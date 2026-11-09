library(pacman)

p_load(here, tidyverse, fixest, modelsummary, broom)


panel_monthly <- read_csv(here("data/clean/merged_data/panel_monthly.csv"), na = "")


# 12-month changes, one series per country-tier. complete() adds the few missing months as blank rows so lag() always steps back one month
reg_monthly <- panel_monthly |>
  complete(nesting(iso2, tier), month) |>
  group_by(iso2, tier) |>
  arrange(month, .by_group = TRUE) |>
  mutate(
    d12_exports = log(exports_chf) - log(lag(exports_chf, 12)),
    d12_equity_l1 = log(lag(equity_index, 1)) - log(lag(equity_index, 13)), #12-month change up to last month
    d12_fx_l1 = log(lag(chf_per_lcu, 1)) - log(lag(chf_per_lcu, 13))
  ) |>
  ungroup()


# Full sample: equity and FX slopes by tier. Tier x month FE remove global shocks to a tier (e.g. Apple Watch on quartz)
equity_monthly <- feols(
  d12_exports ~ i(tier, d12_equity_l1) + i(tier, d12_fx_l1) | iso2^tier + tier^month,
  data = reg_monthly,
  cluster = ~iso2
)

# Country x year FE absorb anything that moves a country for a whole year (GDP growth, recessions, policy shocks)
equity_monthly_cy <- feols(
  d12_exports ~ i(tier, d12_equity_l1) + i(tier, d12_fx_l1) | iso2^tier + tier^month + iso2^year,
  data = mutate(reg_monthly, year = year(month)),
  cluster = ~iso2
)

monthly_rows <- tribble(
  ~term, ~`(1)`, ~`(2)`,
  "FX change × tier", "Yes", "Yes",
  "Country × tier FE", "Yes", "Yes",
  "Tier × month FE", "Yes", "Yes",
  "Country × year FE", "", "Yes"
)
attr(monthly_rows, "position") <- 9:12 #put these rows right under the coefficients

modelsummary(
  list("(1)" = equity_monthly, "(2)" = equity_monthly_cy),
  title = "Stock Market Gains and Swiss Watch Exports, Monthly",
  coef_map = c(
    "tier::precious_mech:d12_equity_l1" = "Precious mechanical",
    "tier::precious_quartz:d12_equity_l1" = "Precious quartz",
    "tier::steel_mech:d12_equity_l1" = "Steel mechanical",
    "tier::steel_quartz:d12_equity_l1" = "Steel quartz"
  ),
  gof_map = tribble(
    ~raw, ~clean, ~fmt,
    "nobs", "Observations", 0,
    "r2.within", "Within R²", 3
  ),
  add_rows = monthly_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = c(
    "Coefficients are the effect of last month's 12-month stock market change on the 12-month change in export value, by watch tier.",
    "All changes in logs. 15 countries. Standard errors clustered by country in parentheses."
  )
)


# Rolling 5-year windows, one regression per window ending each December
window_ends <- seq(as.Date("2005-12-01"), as.Date("2025-12-01"), by = "year")

rolling_equity <- map_dfr(window_ends, function(end) {
  feols(
    d12_exports ~ i(tier, d12_equity_l1) + i(tier, d12_fx_l1) | iso2^tier + tier^month,
    data = filter(reg_monthly, month > end %m-% months(60), month <= end),
    cluster = ~iso2
  ) |>
    tidy(conf.int = TRUE) |>
    filter(str_detect(term, "d12_equity_l1")) |>
    mutate(window_end = year(end))
}) |>
  mutate(tier = str_extract(term, "precious_mech|precious_quartz|steel_mech|steel_quartz"))

rolling_plot <- rolling_equity |>
  ggplot(aes(x = window_end, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) +
  geom_line() +
  facet_wrap(~ tier, nrow = 1) +
  labs(
    x = "End of 5-year window",
    y = "Equity elasticity (95% interval)",
    title = "How Strongly Watch Exports Track Stock Markets, Rolling 5-Year Windows",
    caption = "12-month changes, equity lagged one month, FX controls, country × tier and tier × month FE. Core 15 countries."
  )

rolling_plot
ggsave(here("output/figures", "rolling_equity_elasticity.png"), rolling_plot, width = 10, height = 4, dpi = 300)
