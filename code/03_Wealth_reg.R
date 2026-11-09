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
  "(1)" = wealth_pooled,
  "(2)" = wealth_tier,
  "(3)" = wealth_controls,
  "(4)" = wealth_equity
)

wealth_coefs <- c(
  "log_top1" = "Top 1% share (all tiers)",
  "tier::precious_mech:log_top1" = "Top 1% × precious mechanical",
  "tier::precious_quartz:log_top1" = "Top 1% × precious quartz",
  "tier::steel_mech:log_top1" = "Top 1% × steel mechanical",
  "tier::steel_quartz:log_top1" = "Top 1% × steel quartz",
  "tier::precious_mech:log_equity" = "Equity × precious mechanical",
  "tier::precious_quartz:log_equity" = "Equity × precious quartz",
  "tier::steel_mech:log_equity" = "Equity × steel mechanical",
  "tier::steel_quartz:log_equity" = "Equity × steel quartz"
)

wealth_rows <- tribble(
  ~term, ~`(1)`, ~`(2)`, ~`(3)`, ~`(4)`,
  "GDP per capita, total GDP, RER", "", "", "Yes", "Yes",
  "Country × tier FE", "Yes", "Yes", "Yes", "Yes",
  "Tier × year FE", "Yes", "Yes", "Yes", "Yes"
)
attr(wealth_rows, "position") <- 19:21 #right under the 9 coefficients

modelsummary(
  wealth_models,
  title = "Top 1% Income Share, Stock Markets and Swiss Watch Exports, Annual",
  coef_map = wealth_coefs,
  gof_map = tribble(
    ~raw, ~clean, ~fmt,
    "nobs", "Observations", 0,
    "r2.within", "Within R²", 3,
    "r2.within.adjusted", "Within R² (adjusted)", 3
  ),
  add_rows = wealth_rows,
  stars = c("*" = 0.1, "**" = 0.05, "***" = 0.01),
  notes = c(
    "Dependent variable: log export value. All variables in logs, so coefficients are elasticities.",
    "Column 4 adds equity, which limits the sample to the 15 countries with a stock index. Standard errors clustered by country in parentheses."
  )
)



#Top 1% and equity slopes by tier from the full model, with 95% intervals
wealth_ci <- confint(wealth_equity)

wealth_coef_plot_data <- tibble(
  term = names(coef(wealth_equity)),
  estimate = coef(wealth_equity),
  low = wealth_ci[, 1],
  high = wealth_ci[, 2]
) |>
  filter(str_detect(term, "log_top1|log_equity")) |>
  mutate(
    variable = if_else(str_detect(term, "log_top1"), "Top 1% income share", "Equity index"),
    tier = str_extract(term, "precious_mech|precious_quartz|steel_mech|steel_quartz")
  )

wealth_coef_plot <- wealth_coef_plot_data |>
  ggplot(aes(x = estimate, y = tier)) +
  geom_vline(xintercept = 0, color = "grey50") +
  geom_pointrange(aes(xmin = low, xmax = high)) +
  facet_wrap(~ variable, scales = "free_x") +
  labs(
    x = "Elasticity of watch exports (95% interval)",
    y = NULL,
    title = "How Watch Exports Respond to Top-End Income and Stock Markets",
    caption = "Full annual model: GDP per capita, total GDP and RER controls, country × tier and tier × year FE. Core 15 countries."
  )

wealth_coef_plot
ggsave(here("output/figures", "wealth_coefficients.png"), wealth_coef_plot, width = 9, height = 4.5, dpi = 300)


