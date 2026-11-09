# Paper Map

How every table and figure in `output/` fits into the paper, what each one says, and where it goes. Last updated Nov 9, 2026.

## The story

The title gives the structure: fewer, pricier, richer. The decomposition splits export growth into those three pieces, and each regression explains one of them.

| Piece | The fact | What explains it |
| --- | --- | --- |
| Fewer (volume −0.69 log points, 2012–25) | Units fall while value rises | Smartwatches. Steel quartz falls about 75% relative to steel mechanical, starting around 2017 (DiD) |
| Pricier (price +0.63) | Same-watch prices are 2.6× their 2000 level, CPI is 1.15× | Not gold. Pass-through is null, so this looks like pricing power, not input costs |
| Richer (mix +0.25) | Over-3,000 share of value goes from about a third to 80%. Mechanical goes from 48% to 87% of value | Wealth lifts all tiers about equally, so the mix shift isn't rich buyers trading up. More likely the bottom fell out (quartz) and brands moved upmarket |

The plan's hypothesis was that wealth and gold drive the top tier and smartwatches hit the bottom. One part holds (smartwatches) and two don't (wealth isn't top-specific, gold doesn't pass through). The nulls help the story: the price surge looks like brand strategy, not demand from the rich or the cost of gold.

To check before writing it as a finding: the "bottom fell out" explanation for the mix term is an interpretation. Redo the mix term without steel quartz and see how much is left.

## Reading the annual wealth table

The top 1% elasticities in column 4 are nearly the same across tiers:

| Tier | Elasticity | SE | Stars |
| --- | --- | --- | --- |
| Precious mechanical | 0.833 | 0.665 | |
| Precious quartz | 0.815 | 0.421 | * |
| Steel quartz | 0.811 | 0.312 | ** |
| Steel mechanical | 1.775 | 0.842 | * |

The stars differ because of the standard errors, not the effects. Steel quartz is estimated most precisely because it has the most shipments and the steadiest series. The tier-difference table confirms it: the gaps from steel quartz are 0.02, 0.00 and 0.96, none significant. A significant coefficient next to an insignificant one doesn't mean the effects differ.

What I can say: a rising top 1% share raises Swiss watch imports by about 0.8% per 1%, in every tier alike, with no luxury premium. The robustness table adds that the effect comes through units, not price, and that it weakens without HK, SG and AE (only steel mechanical stays significant).

## Where each output goes

### Main text

| Section | Output | What it says |
| --- | --- | --- |
| 1. Intro | `figures/value_vs_units.png` | Value is about 2.5× its 2000 level while units are down about 40%. Cover candidate |
| 2. Facts | `figures/tier_composition.png` | Over-3,000 band goes from a third to 80% of value |
| | `figures/mechanical_watch_share.png` | Mechanical is 87% of value but only about 37% of units |
| | `figures/top_destinations.png` | HK collapses (4.1 to 1.7bn CHF), the US doubles, JP, GB and SG grow |
| | `tables/growth_by_tier.csv` (T1) | 2019–25: precious value +33–38% while units fall; steel quartz units −30% |
| 3. Decomposition | `figures/decomposition_waterfall.png` | The headline: −0.69 volume, +0.63 price, +0.25 mix = +0.19 total |
| | `figures/price_index_vs_cpi.png` | Same-watch prices far outrun inflation and speed up after 2019 |
| | `figures/decomposition_by_year.png` | Price is positive every year since 2015; volume drives the crashes (2009, 2020) |
| 4a. Smartwatches | `Regressions_output/smartwatch_did.rds`, `figures/smartwatch_event_study.png` | Strongest causal result. Be upfront about the 2000–06 pre-trend; column 3 (−0.53) is the conservative number |
| 4b. Wealth | `Regressions_output/wealth_annual.rds`, `Regressions_output/wealth_robustness.rds` | Broad, quantity-driven top 1% effect; equity not significant annually |
| 4c. Gold | `figures/gold_passthrough.png` | A clear null. Short section |

### Appendix

- `Regressions_output/wealth_tier_diff.rds`: one sentence in the text, table here.
- `figures/wealth_coefficients.png`: a picture of column 4. Use either it or the table in the main text, not both.
- `Regressions_output/wealth_monthly.rds` and `figures/rolling_equity_elasticity.png`: equity predicts the quartz tiers monthly, but that goes away with country × year FE. The rolling elasticity drifts up after 2020 but the bands mostly include 0. Supporting detail, not a finding.
- `figures/unitvalue_ridgeline.png`: a second hump grows around CHF 3,000 after 2015. The K-shape seen in the distribution; partly repeats `tier_composition`.
- `Regressions_output/gold_passthrough.rds`: the figure already shows it.

### Cut

- `figures/polarization_index.png`: the monthly version of the over-3,000 share in `tier_composition`. It was built for forecasting, which is dropped.
- `tables/decomposition_annual.csv` as a paper table: the two decomposition figures carry it.

## Figure polish

Done Nov 9, 2026. All figures regenerated.

- [x] `value_vs_units`: legend now reads "Pieces exported" and "Export value (CHF)", added a title (`02_Descriptives.R`).
- [x] `mechanical_watch_share`: legend now reads "Share of export value" and "Share of pieces" (`02_Descriptives.R`).
- [x] `tier_composition`: bands renamed (Under CHF 200 ... Over CHF 3,000) and put in price order. Year is now numeric, so the 5-year gaps before 2020 show as real gaps (`02_Descriptives.R`).
- [x] `wealth_coefficients`: readable tier names, precious mechanical at the top (`03_Wealth_reg.R`).
- [x] `rolling_equity_elasticity`: readable panel titles, and fewer year ticks so labels don't run together between panels (`03_Wealth_monthly.R`).
- [x] `unitvalue_ridgeline`: zoomed to the data, x-axis labeled in CHF (20 to 100,000) on a log scale, partial-year 2026 dropped (`02_Descriptives.R`).

Still open:

- `tier_composition` only has FH band data for 2000, 2005, 2010, 2015 and 2020–25, so the gaps are real missing years, not a plotting choice. Say so in the figure note.
- The regression tables didn't need changes. They already have titles, notes and clean labels.
