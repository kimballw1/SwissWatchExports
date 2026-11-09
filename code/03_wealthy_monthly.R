library(pacman)

p_load(here, tidyverse, fixest, modelsummary, broom)


# The following code runs tests the relationship between 12 month growth-rate and the 12 month
# growth in the stock market. 
# 
# A rollowing 


panel_monthly <- read_csv(here("data/clean/merged_data/panel_monthly.csv"), na = "")


# 12-month changes, one series per country-tier. complete() adds missing months as blank rows so lag() always steps back one month
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


# Full sample: equity and FX slopes by tier
equity_monthly <- feols(
  d12_exports ~ i(tier, d12_equity_l1) + i(tier, d12_fx_l1) | iso2^tier + month,
  data = reg_monthly,
  cluster = ~iso2
)

modelsummary(
  list("Monthly" = equity_monthly),
  coef_map = c(
    "tier::precious_mech:d12_equity_l1" = "Equity change × precious mech",
    "tier::precious_quartz:d12_equity_l1" = "Equity change × precious quartz",
    "tier::steel_mech:d12_equity_l1" = "Equity change × steel mech",
    "tier::steel_quartz:d12_equity_l1" = "Equity change × steel quartz"
  ),
  gof_map = c("nobs", "r2.within"),
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = "Dependent variable: 12-month log change in export value. Equity and FX are 12-month log changes up to the month before. FX × tier controls, country × tier and month FE. Core 15 countries. Standard errors clustered by country."
)


# Rolling 5-year windows, one regression per window ending each December
window_ends <- seq(as.Date("2005-12-01"), as.Date("2025-12-01"), by = "year")

rolling_equity <- map_dfr(window_ends, function(end) {
  feols(
    d12_exports ~ i(tier, d12_equity_l1) + i(tier, d12_fx_l1) | iso2^tier + month,
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
    caption = "12-month changes, equity lagged one month, FX controls, country × tier and month FE. Core 15 countries."
  )

rolling_plot
ggsave(here("output/figures", "rolling_equity_elasticity.png"), rolling_plot, width = 10, height = 4, dpi = 300)



