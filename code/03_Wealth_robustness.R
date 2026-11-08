library(pacman)

p_load(here, tidyverse, fixest, modelsummary)


panel_annual <- read_csv(here("data/clean/merged_data/panel_annual.csv"), na = "")

reg_annual <- panel_annual |>
  mutate(
    log_exports = log(exports_chf),
    log_units = log(units),
    log_unit_value = log(unit_value),
    log_top1 = log(top1_income),
    log_gdp_pc = log(gdp_pc_ppp),
    log_gdp = log(gdp_const_usd),
    log_equity = log(equity_index),
    log_rer = log(rer)
  )


# Tier differences: steel quartz is the base, each tier row is its slope minus steel quartz's
wealth_diff <- feols(
  log_exports ~ log_top1 + i(tier, log_top1, ref = "steel_quartz") + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

diff_coefs <- c(
  "log_top1" = "Top 1% share (steel quartz slope)",
  "tier::precious_mech:log_top1" = "Precious mech minus steel quartz",
  "tier::precious_quartz:log_top1" = "Precious quartz minus steel quartz",
  "tier::steel_mech:log_top1" = "Steel mech minus steel quartz"
)

diff_rows <- tribble(
  ~term, ~`Tier differences`,
  "GDP per capita, total GDP, RER, equity", "X",
  "Country × tier FE", "X",
  "Tier × year FE", "X"
)

modelsummary(
  list("Tier differences" = wealth_diff),
  coef_map = diff_coefs,
  gof_map = "nobs",
  add_rows = diff_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = "Dependent variable: log export value. All variables in logs. Standard errors clustered by country (15 clusters) in parentheses."
)


# Robustness: drop the hubs, and split value into units and unit value
wealth_base <- feols(
  log_exports ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

wealth_no_hubs <- feols(
  log_exports ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = filter(reg_annual, !iso2 %in% c("HK", "SG", "AE")),
  cluster = ~iso2
)

wealth_units <- feols(
  log_units ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

wealth_unit_value <- feols(
  log_unit_value ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

robust_models <- list(
  "Baseline" = wealth_base,
  "Drop hubs" = wealth_no_hubs,
  "Units" = wealth_units,
  "Unit value" = wealth_unit_value
)

robust_coefs <- c(
  "tier::precious_mech:log_top1" = "Top 1% share × precious mech",
  "tier::precious_quartz:log_top1" = "Top 1% share × precious quartz",
  "tier::steel_mech:log_top1" = "Top 1% share × steel mech",
  "tier::steel_quartz:log_top1" = "Top 1% share × steel quartz",
  "tier::precious_mech:log_equity" = "Equity index × precious mech",
  "tier::precious_quartz:log_equity" = "Equity index × precious quartz",
  "tier::steel_mech:log_equity" = "Equity index × steel mech",
  "tier::steel_quartz:log_equity" = "Equity index × steel quartz"
)

robust_rows <- tribble(
  ~term, ~Baseline, ~`Drop hubs`, ~Units, ~`Unit value`,
  "Dependent variable", "Value", "Value", "Units", "Unit value",
  "GDP per capita, total GDP, RER", "X", "X", "X", "X",
  "Country × tier FE", "X", "X", "X", "X",
  "Tier × year FE", "X", "X", "X", "X"
)

modelsummary(
  robust_models,
  coef_map = robust_coefs,
  gof_map = c("nobs", "r2.within"),
  add_rows = robust_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = "All variables in logs. Drop hubs removes HK, SG and AE. Units + unit value add up to the baseline. Standard errors clustered by country in parentheses."
)
