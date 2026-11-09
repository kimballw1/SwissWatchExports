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
  "log_top1" = "Steel quartz slope (base)",
  "tier::precious_mech:log_top1" = "Precious mechanical minus steel quartz",
  "tier::precious_quartz:log_top1" = "Precious quartz minus steel quartz",
  "tier::steel_mech:log_top1" = "Steel mechanical minus steel quartz"
)

diff_rows <- tribble(
  ~term, ~`(1)`,
  "GDP per capita, total GDP, RER, equity", "Yes",
  "Country × tier FE", "Yes",
  "Tier × year FE", "Yes"
)
attr(diff_rows, "position") <- 9:11 #right under the 4 coefficients

modelsummary(
  list("(1)" = wealth_diff),
  title = "Does the Top 1% Effect Differ by Tier?",
  coef_map = diff_coefs,
  gof_map = tribble(
    ~raw, ~clean, ~fmt,
    "nobs", "Observations", 0
  ),
  add_rows = diff_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = c(
    "Top 1% income share slope for steel quartz, and how much each other tier's slope differs from it. Dependent variable: log export value.",
    "15 countries. Standard errors clustered by country in parentheses."
  )
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
  "(1)" = wealth_base,
  "(2)" = wealth_no_hubs,
  "(3)" = wealth_units,
  "(4)" = wealth_unit_value
)

robust_coefs <- c(
  "tier::precious_mech:log_top1" = "Top 1% × precious mechanical",
  "tier::precious_quartz:log_top1" = "Top 1% × precious quartz",
  "tier::steel_mech:log_top1" = "Top 1% × steel mechanical",
  "tier::steel_quartz:log_top1" = "Top 1% × steel quartz",
  "tier::precious_mech:log_equity" = "Equity × precious mechanical",
  "tier::precious_quartz:log_equity" = "Equity × precious quartz",
  "tier::steel_mech:log_equity" = "Equity × steel mechanical",
  "tier::steel_quartz:log_equity" = "Equity × steel quartz"
)

robust_rows <- tribble(
  ~term, ~`(1)`, ~`(2)`, ~`(3)`, ~`(4)`,
  "Dependent variable (log)", "Value", "Value", "Units", "Unit value",
  "Sample", "All 15", "No HK, SG, AE", "All 15", "All 15",
  "GDP per capita, total GDP, RER", "Yes", "Yes", "Yes", "Yes",
  "Country × tier FE", "Yes", "Yes", "Yes", "Yes",
  "Tier × year FE", "Yes", "Yes", "Yes", "Yes"
)
attr(robust_rows, "position") <- c(1, 2, 19, 20, 21) #outcome and sample on top, controls under the 8 coefficients

modelsummary(
  robust_models,
  title = "Wealth Regression Robustness: Dropping Hubs and Splitting Value into Units and Price",
  coef_map = robust_coefs,
  gof_map = tribble(
    ~raw, ~clean, ~fmt,
    "nobs", "Observations", 0,
    "r2.within", "Within R²", 3
  ),
  add_rows = robust_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = c(
    "All variables in logs. Column 2 drops the re-export hubs. Columns 3 and 4 add up to column 1.",
    "Standard errors clustered by country in parentheses."
  )
)
