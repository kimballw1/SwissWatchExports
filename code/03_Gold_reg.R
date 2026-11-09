# Gold pass-through: do gold price changes show up in precious-metal watch prices over the next 12 months?

library(pacman)

p_load(here, tidyverse, fixest, modelsummary)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")


# Monthly gold change and its lags 0-12 (gold has no gaps, so lag by month here)
gold_lags <- panel_line |>
  distinct(month, gold_chf) |>
  arrange(month) |>
  mutate(dlog_gold = log(gold_chf) - log(lag(gold_chf)))

for (j in 0:12) {
  gold_lags[[paste0("gold_l", j)]] <- lag(gold_lags$dlog_gold, j)
}

# Monthly FX change and its lags 0-3, by country
fx_lags <- panel_line |>
  distinct(iso2, month, chf_per_lcu) |>
  filter(!is.na(chf_per_lcu)) |>
  group_by(iso2) |>
  arrange(month, .by_group = TRUE) |>
  mutate(
    dlog_fx = log(chf_per_lcu) - log(lag(chf_per_lcu)),
    fx_l0 = dlog_fx,
    fx_l1 = lag(dlog_fx, 1),
    fx_l2 = lag(dlog_fx, 2),
    fx_l3 = lag(dlog_fx, 3)
  ) |>
  ungroup() |>
  select(iso2, month, starts_with("fx_l"))

# Change in log unit value within each line-country, only when last month was shipped too
reg_gold <- panel_line |>
  filter(!is.na(chf_per_lcu)) |>
  group_by(tariff_line, iso2) |>
  arrange(month, .by_group = TRUE) |>
  mutate(
    dlog_uv = if_else(
      lag(month) == month %m-% months(1),
      log(unit_value) - log(lag(unit_value)),
      NA
    )
  ) |>
  ungroup() |>
  filter(!is.na(dlog_uv)) |>
  mutate(
    dlog_uv = pmin(pmax(dlog_uv, quantile(dlog_uv, 0.01)), quantile(dlog_uv, 0.99)), #winsorize at 1% / 99%
    precious = if_else(str_starts(tier, "precious"), 1, 0)
  ) |>
  left_join(select(gold_lags, month, starts_with("gold_l")), by = "month") |>
  left_join(fx_lags, by = c("iso2", "month")) |>
  mutate(across(starts_with("gold_l"), \(x) x * precious, .names = "p{.col}"))


# Pass-through: extra response of precious-case unit values to gold, relative to steel
gold_vars <- paste0("pgold_l", 0:12)
fx_vars <- paste0("fx_l", 0:3)

gold_pt <- feols(
  dlog_uv ~ .[gold_vars] + .[fx_vars] | tariff_line^iso2 + month,
  data = reg_gold,
  weights = ~units,
  cluster = ~iso2
)


# Cumulative pass-through after 0-12 months, with its standard error
gold_vcov <- vcov(gold_pt)[gold_vars, gold_vars]

gold_cumulative <- tibble(lag = 0:12) |>
  mutate(
    estimate = cumsum(coef(gold_pt)[gold_vars]),
    se = map_dbl(lag, \(k) sqrt(sum(gold_vcov[1:(k + 1), 1:(k + 1)])))
  )

gold_plot <- gold_cumulative |>
  ggplot(aes(x = lag, y = estimate)) +
  geom_hline(yintercept = 0, color = "grey50") +
  geom_ribbon(aes(ymin = estimate - 1.96 * se, ymax = estimate + 1.96 * se), alpha = 0.2) +
  geom_line() +
  geom_point() +
  scale_x_continuous(breaks = 0:12) +
  labs(
    x = "Months after the gold price change",
    y = "Cumulative pass-through (elasticity)",
    title = "Gold Price Pass-Through to Precious-Metal Watch Prices",
    caption = "Extra response of precious-case unit values relative to steel. Band: 95% CI, clustered by country."
  )

gold_plot
ggsave(here("output/figures", "gold_passthrough.png"), gold_plot, width = 8, height = 5, dpi = 300)


# Table: cumulative effect at 0, 3, 6 and 12 months
gold_table <- gold_cumulative |>
  filter(lag %in% c(0, 3, 6, 12)) |>
  transmute(
    `Months after gold change` = as.character(lag),
    `Cumulative pass-through` = estimate,
    `Std. error` = se
  )

datasummary_df(
  gold_table,
  fmt = 3,
  title = "Gold Price Pass-Through to Precious-Metal Watch Prices",
  notes = "Extra % change in precious-metal watch unit values after a 1% gold price rise, relative to steel watches. Standard errors clustered by country."
)
