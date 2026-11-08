library(pacman)

p_load(here, tidyverse, fixest, modelsummary, stargazer)


panel_annual <- read_csv(here("data/clean/merged_data/panel_annual.csv"), na = "")


#checking for no zero export values so we can log Finding: (no zeroes)
# panel_annual |>
# filter(exports_chf == 0)

#logging variables to coefficients into elasticities later/ put all the various units on a common percent scale and to correct for skew
reg_annual <- panel_annual |> 
  mutate(
    log_exports = log(exports_chf),
    log_top1 = log(top1_income), #income share of the top 1%
    log_gdp_pc = log(gdp_pc_ppp), #gdp per capita
    log_gdp = log(gdp_const_usd), #total gdp (constant USD)
    log_equity = log(equity_index),
    log_rer = log(rer) #RER (real exchange rate)
  )


# Pooled slope
wealth_pooled <- feols(
  log_exports ~ log_top1 | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

# Tier-specific slope
wealth_tier <- feols(
  log_exports ~ i(tier, log_top1) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

# Controls
wealth_controls <- feols(
  log_exports ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

wealth_equity <- feols(
  log_exports ~ i(tier, log_top1) + i(tier, log_gdp_pc) + i(tier, log_gdp) + i(tier, log_rer) + i(tier, log_equity) | iso2^tier + tier^year,
  data = reg_annual,
  cluster = ~iso2
)

# Table
wealth_models <- list(
  "Pooled" = wealth_pooled,
  "By tier" = wealth_tier,
  "+ GDP, RER" = wealth_controls,
  "+ Equity" = wealth_equity
)

wealth_coefs <- c(
  "log_top1" = "Top 1% share",
  "tier::precious_mech:log_top1" = "Top 1% share × precious mech",
  "tier::precious_quartz:log_top1" = "Top 1% share × precious quartz",
  "tier::steel_mech:log_top1" = "Top 1% share × steel mech",
  "tier::steel_quartz:log_top1" = "Top 1% share × steel quartz",
  "tier::precious_mech:log_equity" = "Equity index × precious mech",
  "tier::precious_quartz:log_equity" = "Equity index × precious quartz",
  "tier::steel_mech:log_equity" = "Equity index × steel mech",
  "tier::steel_quartz:log_equity" = "Equity index × steel quartz"
)

wealth_rows <- tribble(
  ~term, ~Pooled, ~`By tier`, ~`+ GDP, RER`, ~`+ Equity`,
  "GDP per capita, total GDP, RER", "", "", "X", "X",
  "Country × tier FE", "X", "X", "X", "X",
  "Tier × year FE", "X", "X", "X", "X"
)

modelsummary(
  wealth_models,
  coef_map = wealth_coefs,
  gof_map = c("nobs", "r2.within", "r2.within.adjusted"),
  add_rows = wealth_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = "Dependent variable: log export value. All variables in logs. Standard errors clustered by country in parentheses."
)




