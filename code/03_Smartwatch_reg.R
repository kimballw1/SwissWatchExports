library(pacman)

p_load(here, tidyverse, fixest, modelsummary)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")


# 12-month change in the exchange rate, one row per country-month
fx_change <- panel_line |>
  distinct(iso2, month, chf_per_lcu) |>
  filter(!is.na(chf_per_lcu)) |>
  group_by(iso2) |>
  arrange(month, .by_group = TRUE) |>
  mutate(dlog_fx_12 = log(chf_per_lcu) - log(lag(chf_per_lcu, 12))) |>
  ungroup() |>
  select(iso2, month, dlog_fx_12)

# Steel lines only (9102), wide 22 (the countries with FX)
reg_smart <- panel_line |>
  filter(str_starts(tariff_line, "9102"), !is.na(chf_per_lcu)) |>
  left_join(fx_change, by = c("iso2", "month")) |>
  mutate(
    log_units = log(units),
    quartz = if_else(tier == "steel_quartz", 1, 0),
    quartz_post = quartz * apple_watch,
    quartz_fx = quartz * dlog_fx_12,
    year = year(month),
    trend = (year(month) - 2000) * 12 + month(month)
  )


# Diff-in-diff: quartz (treated) vs mechanical (control), post = May 2015 on
smart_did <- feols(
  log_units ~ quartz_post | tariff_line^iso2 + iso2^month,
  data = reg_smart,
  cluster = ~iso2
)

# Quartz may react more to the franc (unpeg Jan 2015)
smart_fx <- feols(
  log_units ~ quartz_post + quartz_fx | tariff_line^iso2 + iso2^month,
  data = reg_smart,
  cluster = ~iso2
)

# Quartz was already declining: line-specific linear trends
smart_trends <- feols(
  log_units ~ quartz_post + quartz_fx | tariff_line^iso2 + iso2^month + tariff_line[trend],
  data = reg_smart,
  cluster = ~iso2
)

smart_models <- list(
  "(1)" = smart_did,
  "(2)" = smart_fx,
  "(3)" = smart_trends
)

smart_coefs <- c(
  "quartz_post" = "Quartz × after Apple Watch (May 2015)",
  "quartz_fx" = "Quartz × 12-month FX change"
)

smart_rows <- tribble(
  ~term, ~`(1)`, ~`(2)`, ~`(3)`,
  "Line × country FE", "Yes", "Yes", "Yes",
  "Country × month FE", "Yes", "Yes", "Yes",
  "Line-specific trends", "", "", "Yes"
)
attr(smart_rows, "position") <- 5:7 #right under the 2 coefficients

modelsummary(
  smart_models,
  title = "Smartwatches and Swiss Quartz Exports: Difference-in-Differences",
  coef_map = smart_coefs,
  gof_map = tribble(
    ~raw, ~clean, ~fmt,
    "nobs", "Observations", 0,
    "r2.within", "Within R²", 3
  ),
  add_rows = smart_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = c(
    "Dependent variable: log pieces. Steel watches only: quartz (treated) vs mechanical (control).",
    "22 countries, monthly 2000-2026. Standard errors clustered by country in parentheses."
  )
)


# Event study: quartz vs mechanical gap by year, 2014 = 0
smart_es <- feols(
  log_units ~ i(year, quartz, ref = 2014) | tariff_line^iso2 + iso2^month,
  data = reg_smart,
  cluster = ~iso2
)

es_coefs <- as_tibble(coeftable(smart_es), rownames = "term") |>
  transmute(
    year = parse_number(str_extract(term, "\\d{4}")),
    estimate = Estimate,
    se = `Std. Error`
  ) |>
  add_row(year = 2014, estimate = 0, se = 0)

smart_es_plot <- es_coefs |>
  ggplot(aes(x = year, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_vline(xintercept = 2014.5, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se)) +
  labs(
    x = "Year",
    y = "Quartz vs mechanical, log pieces (2014 = 0)",
    title = "Steel Quartz vs Steel Mechanical Exports Around the Apple Watch",
    caption = "Dashed line: Apple Watch launch (Apr 2015). Bars: 95% confidence intervals, clustered by country."
  )

smart_es_plot
ggsave(here("output/figures", "smartwatch_event_study.png"), smart_es_plot, width = 8, height = 5, dpi = 300)
