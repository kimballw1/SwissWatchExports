# Swiss Watch Market Project Plan

Nov 1, 2026 · Kimball Weeks

## Overview

The Swiss watch industry ships far fewer watches than it did 15 years ago and earns more doing it. The paper documents that shift, explains it with regressions, and forecasts where it goes next. Working title: *Understanding the Swiss Watch Market*

The paper runs in three acts: what happened, why, and what comes next.

| Act | Research question | Method |
| --- | --- | --- |
| What happened | RQ1. How much of export value growth is volume, price, and product mix? | Shift-share decomposition |
| What happened | RQ2. How has the destination map shifted, and did mechanical take over? | Descriptives, ranks, shares |
| Why | RQ3. Does top-end wealth drive demand for the top tier but not the bottom? | Panel regression (wealth) |
| Why | RQ4. Did smartwatches hollow out cheap quartz after April 2015? | Diff-in-diff + event study |
| Why | RQ5. Do gold prices pass through to precious-metal watch prices? | Distributed-lag pass-through regression |
| What next | RQ6. Can we forecast exports by tier and destination, and do wealth signals help the top tier most? | Forecast comparison, counterfactuals, scenarios |

Main hypothesis tying it together: the top tier is driven by wealth and gold, the bottom tier was hit by smartwatches, and the middle got squeezed from both sides.

**Tier definitions from tariff lines.** HS 9101 is precious-metal cases, 9102 is everything else (mostly steel). Within each, subheadings .11/.12/.19 are electric (quartz) and .21/.29 are mechanical (automatic, manual). That gives a fixed 2 × 2 that, unlike FH price tiers, doesn't shift when prices change:

| | Quartz | Mechanical |
| --- | --- | --- |
| Precious metal (9101) | 9101.11, .19 | 9101.21, .29 |
| Steel/other (9102) | 9102.11, .12, .19 | 9102.21, .29 |

Unit value = export value / pieces, per line × country × month. Use FH price tiers for the headline story and forecasting, and tariff-line groups for regressions, where a fixed definition matters.

**Shock dates as dummies:** Dec 2012 (China anti-graft rules), Jan 15 2015 (franc unpegging), Apr 24 2015 (Apple Watch launch), mid 2019 (Hong Kong protests), Mar 2020 to mid 2021 (COVID), 2025 (US tariff front-loading and drop).

## Module 1: Descriptives and destination shifts (RQ2)

This module sets up the paper with charts only. It covers the K-shape, the rise of mechanical watches, and where the watches go. Write it first, because it shows quickly whether the story holds.

1. Value vs units chart. Total export value and total pieces, indexed to 100 in the base year. The two lines should diverge.
2. Tier composition. Stacked area of value by FH tier, and a second panel for units. Expect the 3,000+ tier to dominate value and the bottom tier to dominate units, with the middle shrinking in both.
3. Unit value ridgeline. One density of log unit value per year (weighted by pieces). The distribution should shift right and lose its middle.
4. Mechanical share. Mechanical share of value and of units, 2000 (or 2012) to now.
5. Destination ranks. Bump chart of the top 10 destinations by value each year, plus small multiples of tier mix by country.
6. Polarization index. Top-tier share of total value, monthly. This is the main number the forecasting module projects forward.

Output: six figures and one summary table of growth rates by tier and period (2012 to 2019, 2019 to 2026).

## Module 2: Price, volume, and mix decomposition (RQ1)

This module splits each year's change in export value into three parts: selling more or fewer watches (volume), charging more for the same kind of watch (price), and selling more of the pricey kinds (mix). The headline sentence: "X% of value growth since 2012 is price, Y% is mix, and volume subtracted Z%."

Let $i$ index tariff lines, with value $V_{it}$, pieces $q_{it}$ and unit value $p_{it} = V_{it} / q_{it}$. Total value $V_t$, total pieces $Q_t$, and average unit value $P_t = V_t / Q_t$. Then:

$$
\Delta \ln V_t = \underbrace{\Delta \ln Q_t}_{\text{volume}} + \underbrace{\sum_i \bar{s}_{it}\, \Delta \ln p_{it}}_{\text{price (Törnqvist)}} + \underbrace{\Big[\Delta \ln P_t - \sum_i \bar{s}_{it}\, \Delta \ln p_{it}\Big]}_{\text{mix}}
$$

where $\bar{s}_{it}$ is the average of line $i$'s value share in $t$ and $t-1$. The three parts add up exactly, so the waterfall chart always reconciles.

Steps:

1. Compute annual log changes at the tariff-line level (about 10 lines). Use annual data so monthly noise doesn't swamp the mix term.
2. Plot a stacked bar per year (volume, price, mix) with total value change as a dot, plus one cumulative waterfall from 2012 to 2025.
3. Build a Swiss watch price index by chaining the Törnqvist term, then plot it against Swiss CPI. The gap is real luxury price growth.
4. Robustness: redo at tariff line × country, so mix also picks up shifts toward pricier destinations. Then compare against the line-only version.
5. Run the same split by FH tier to show that the top tier grows through price and mix while the bottom tier shrinks through volume.

This feeds Module 4: forecast volume, price and mix separately and recombine them, then check whether that beats forecasting value directly.

## Module 3: Regressions (RQ3 to RQ5)

Three regressions explain the shift. Wealth pulls the top tier, smartwatches hit the bottom, and gold moves precious-metal prices. All three run in R with fixest, with standard errors clustered by country and tables made with modelsummary.

### 3a. Wealth and the top tier (RQ3)

Annual panel, destination $d$, FH tier $k$, year $t$:

$$
\ln X_{dkt} = \beta_k \ln \text{Top1}_{dt} + \gamma_k \ln \text{GDPpc}_{dt} + \delta_k \ln \text{Equity}_{dt} + \theta_k \ln \text{RER}_{dt} + \alpha_{dk} + \mu_{kt} + \varepsilon_{dkt}
$$

- Prediction: β and δ positive and large for 3,000+, near zero for under 200. γ matters more for the cheap tiers.
- Robustness: wealth share instead of income share, drop the hubs (HK, SG, UAE), a Greater China aggregate, and PPML (fepois) on levels.
- Honest caveat: top shares move slowly within a country, so β may be imprecise. That's fine. Report it, and let the monthly version carry the power.

Monthly version (more power, and it produces the rolling-elasticity chart):

$$
\Delta_{12} \ln X_{dkt} = \sum_k \rho_k \, \Delta_{12} \ln \text{Equity}_{d,t-1} \times \mathbb{1}[k] + \phi_k \, \Delta_{12} \ln \text{FX}_{d,t-1} \times \mathbb{1}[k] + \alpha_{dk} + \mu_t + \varepsilon_{dkt}
$$

Add an Equity × Top1<sub>d,2012</sub> × tier interaction to test whether equity booms matter more for watches in more unequal countries. Re-estimate ρ on rolling 5-year windows and plot it over time, one line per tier.

### 3b. Smartwatches and quartz (RQ4)

Diff-in-diff on steel lines only (9102), so case material is held fixed. Quartz lines are treated, mechanical lines are the control, and the post period starts May 2015. Unit is line ℓ × destination $d$ × month $t$:

$$
\ln q_{\ell dt} = \beta \, (\text{Quartz}_\ell \times \text{Post}_t) + \psi \, (\text{Quartz}_\ell \times \Delta \ln \text{FX}_{dt}) + \alpha_{\ell d} + \mu_{dt} + \varepsilon_{\ell dt}
$$

- Destination × month fixed effects absorb the franc shock and any demand shock that hits both movement types in a market. The Quartz × FX term allows cheap quartz to be more price-sensitive to the franc.
- Event study: swap Post for year-relative dummies (base year 2014) and plot the coefficients. This is where pre-2012 data matters: with 2012 data only, you get 3 pre-years. Quartz was already declining, so also show a version with line-specific trends.
- Run it on pieces (main) and value (secondary).
- Optional intensity variant: compare destinations with high vs low smartwatch adoption (US/UK vs others).

### 3c. Gold pass-through (RQ5)

$$
\Delta \ln p_{\ell dt} = \sum_{j=0}^{12} \lambda_j \, \text{Precious}_\ell \times \Delta \ln \text{Gold}^{CHF}_{t-j} + \sum_{j=0}^{3} \phi_j \, \Delta \ln \text{FX}_{d,t-j} + \alpha_{\ell d} + \mu_t + \varepsilon_{\ell dt}
$$

- Month fixed effects absorb gold's common effect, so λ identifies the extra pass-through to gold-case watches relative to steel. That's the object you want.
- Plot cumulative pass-through Σλ<sub>j</sub> with a 95% band over 0 to 12 months.
- Weight by pieces, and winsorize unit-value changes at 1%/99%, since thin lines have noisy unit values.

## Module 4: Forecasting (RQ6)

**Dropped 2026-11-07.** No forecasting in the paper. RQ6, F12 to F15, T5, the counterfactuals, scenarios and the forecast sandbox visuals go with it. The text below is kept for reference only.

The main forecasting test: wealth and gold predictors should improve forecasts for the 3,000+ tier but not for the under-200 tier. If they do, the forecasts back up the regressions.

### Targets

- Year-over-year growth in monthly export value, by FH tier (main)
- Polarization index: 3,000+ share of total value (headline forecast)
- Hierarchy for reconciliation: total → 4 tiers → top 10 destinations + rest of world

### Setup

- Expanding window. First training sample 2012 to 2018, first forecast Jan 2019, roll monthly through the latest data.
- Horizons h = 1, 3, 6, 12 months.
- Direct forecasting: for horizon h, predictors enter lagged at least h months, so you never have to forecast the S&P.

### Model ladder

| Model | Adds | R package |
| --- | --- | --- |
| Seasonal naive | Same month last year | fable |
| ETS, SARIMA | The series' own dynamics | fable |
| ARIMAX | Lagged equity returns, FX, gold (+ Google Trends if pulled) | fable |
| Decomposed | Forecast volume, price, mix separately, then recombine (Module 2) | fable |
| Pooled LightGBM (optional) | One ML model across all tier × country series | lightgbm |
| Reconciled | Bottom-up and MinT so countries sum to tiers and tiers sum to total | fabletools::reconcile |

### Evaluation

- RMSE and MAE by model × tier × horizon, shown as relative RMSE vs SARIMA (below 1 = better).
- Diebold-Mariano tests for ARIMAX vs SARIMA, by tier. The expected pattern is significant gains for 3,000+ and none for under 200.
- Rolling 12-month RMSE over time with shock periods shaded, showing where each model breaks (COVID, 2023 China, 2025 tariffs).
- Loss-function robustness: rank models under squared and absolute error.

### Counterfactuals (forecasts used as "what would have happened")

- Smartwatch: train on quartz units through Mar 2015, forecast forward, and shade the gap from actual. Do the same for mechanical as a placebo, which should show little gap. This is the visual partner to the 3b diff-in-diff. It needs the pre-2012 data to train well.
- 2025 tariffs: hold out 2025 and test which models caught the US front-loading spike and the drop after it.

### Scenarios and forward forecasts

- Fan charts (80% and 95%) by tier for the next 18 months, plus the polarization index.
- Conditional scenarios from ARIMAX: equity −20%, gold +20%, CHF +10%. Plot each scenario's path against the baseline for the 3,000+ and under-200 tiers.

## Figures and tables

The paper has 15 figures and 5 tables. Starred items are the showpieces. If time runs short, keep the starred ones and drop the rest.

| # | Exhibit | Chart type | Section |
| --- | --- | --- | --- |
| F1* | Value vs units, indexed | Two-line divergence | Descriptives |
| F2 | Value and units by FH tier | Stacked area, 2 panels | Descriptives |
| F3* | Unit value distribution by year | Ridgeline | Descriptives |
| F4 | Mechanical share of value and units | Line | Descriptives |
| F5 | Top 10 destinations by rank | Bump chart | Descriptives |
| F6* | Value change split into volume, price, mix | Stacked bars + cumulative waterfall | Decomposition |
| F7 | Swiss watch price index vs Swiss CPI | Line | Decomposition |
| F8 | Wealth elasticity by tier | Coefficient plot | Regressions 3a |
| F9* | Rolling equity elasticity by tier | Line, one per tier | Regressions 3a |
| F10* | Smartwatch event study | Coefficients with CIs by year | Regressions 3b |
| F11 | Cumulative gold pass-through, 0 to 12 months | Line with band | Regressions 3c |
| F12* | Relative RMSE, model × tier × horizon | Heatmap | Forecasting |
| F13 | Rolling forecast error with shocks shaded | Line | Forecasting |
| F14* | Quartz counterfactual vs actual, gap shaded | Line + ribbon | Forecasting |
| F15* | Fan charts by tier + polarization index, with scenarios | Fan chart | Forecasting |
| T1 | Summary stats and growth by tier and period | Table | Data |
| T2 | Wealth panel (annual + monthly) | Regression table | 3a |
| T3 | Smartwatch DiD | Regression table | 3b |
| T4 | Gold pass-through | Regression table | 3c |
| T5 | Diebold-Mariano tests by tier and horizon | Table | Forecasting |

Stretch goal: a small interactive dashboard (Shiny or a single HTML page) with F15's fan charts and scenario sliders. Make it only after the paper is done.

## Extra visuals (sandbox)

These are optional and use no new data. Draft them all roughly in one script, then keep the best few.

| Visual | Shows | Note |
| --- | --- | --- |
| Year × month YoY heatmap, by tier | Seasonality and shocks as stripes | Top pick |
| Connected scatter: units vs avg unit value | Fewer, pricier watches in one path | Top pick |
| Lorenz curve + Gini by year | Inequality within the watch market | Top pick. Cell averages understate spread, so footnote it |
| Hedgehog plot | Each month's forecast path vs actual, which reveals bias | Top pick. Needs forecast output |
| Seasonal subseries / STL | Whether seasonality differs by tier or has shifted | |
| Event-aligned shock curves | Recovery speed after each shock, indexed to 100 | Anti-graft needs pre-2012 data |
| Marimekko | Destination size × tier mix | |
| Slope chart | Unit value by tariff line, 2012 vs latest | |
| Cross-correlation heatmap | How many months equity leads top-tier exports | 15 equity countries only |
| Interval coverage plot | Whether fan charts are honest | Needs forecast output |
| Polar seasonal, bar chart race | Eye candy | Presentation only |

## Code structure (R)

Use one script per module, each reading from data/clean/ and writing to output/, so any module can rerun on its own.

```
watch-project/
  data/raw/          untouched downloads
  data/clean/        one tidy file per source (kept separate)
  R/00_setup.R       packages, paths, ggplot theme, shock-date dummies
  R/01_clean.R       existing cleaning script + gold, CPI, pre-2012 filter
  R/02_build.R       merges: annual_panel, monthly_panel, line_panel, tsibble for forecasting
  R/03_descriptives.R   F1–F5, T1
  R/04_decomp.R         F6–F7
  R/05_regressions.R    F8–F11, T2–T4
  R/06_forecast.R       expanding-window loop, saves all forecasts to output/forecasts.rds
  R/07_forecast_eval.R  F12–F15, T5
  R/08_viz_sandbox.R    rough drafts of the extra visuals
  output/figures/  output/tables/
```

Packages: tidyverse, fixest, modelsummary, fable, fabletools, tsibble, feasts, ggridges, ggbump, patchwork, plus lightgbm if you do the ML model.

Three build files, each built once in 02_build.R:

- annual_panel: destination × tier × year, with top shares, GDP, equity, RER (3a annual)
- monthly_panel: destination × tier × month, with equity, FX, gold (3a monthly, forecasting)
- line_panel: tariff line × destination × month, with pieces, value, unit value (decomposition, 3b, 3c)

Keep the forecasting loop separate from evaluation. The loop is slow, so run it once, save the forecasts, and iterate on the charts afterward.

## Timeline, scope cuts, open decisions

The plan fits five weeks, assuming the paper is due finals week (about Dec 7). Shift the weeks if the deadline is different.

**Week of Nov 2: data and descriptives**
- [x] Pull gold (World Bank Pink Sheet) and Swiss CPI
- [x] Filter the opendata.swiss bulk file to 9101/9102 for 2000 to 2011
- [x] Build annual_panel, monthly_panel, line_panel
- [x] F1 to F5, T1, and sandbox drafts of the extra visuals. Check the story holds before going further.

**Week of Nov 9: decomposition and wealth regressions**
- [ ] Decomposition, F6 and F7
- [ ] 3a annual and monthly, T2, F8, F9

**Week of Nov 16: smartwatch and gold**
- [x] 3b diff-in-diff and event study, T3, F10
- [x] 3c gold pass-through, T4, F11

**Week of Nov 30: evaluation and writing**
- [ ] F12 to F15, T5, scenarios, hedgehog and coverage plots
- [ ] Write-up: intro, data, three acts, conclusion

If time runs short, cut in this order: dashboard → LightGBM → Google Trends → smartwatch intensity variant → reconciliation → decomposed forecasts. Keep the three regressions, the main forecast comparison, and the starred figures.

**Open decisions for you**
- [ ] Due date and format (paper, presentation, or both). This sets how much the dashboard matters.
- [ ] Whether to pull pre-2012 data. It's about an hour of filtering and makes 3b and the smartwatch counterfactual much stronger. Recommended.
