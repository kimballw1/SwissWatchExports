# Paper Map

## The story

The title gives the structure: fewer, pricier, richer. The decomposition splits export growth into those three pieces, and each regression explains one of them.

| Piece | The fact | What explains it |
| --- | --- | --- |
| Fewer (volume −0.69 log points, 2012–25) | Units fall while value rises | Smartwatches. Steel quartz falls about 75% relative to steel mechanical, starting around 2017 (DiD) |
| Pricier (price +0.63) | Unit values within each tariff line are 2.6× their 2000 level, CPI is 1.15× | Not gold. Pass-through is null, so this is price hikes and upgrading within categories, not input costs |
| Richer (mix +0.25) | Over-3,000 share of value goes from about a third to 80%. Mechanical goes from 48% to 86% of value | The bottom fell out. The whole mix effect comes from steel quartz shrinking (see the mix test below). Wealth lifts all tiers about equally, so it isn't rich buyers trading up |

The plan's hypothesis was that wealth and gold drive the top tier and smartwatches hit the bottom. One part holds (smartwatches) and two don't (wealth isn't top-specific, gold doesn't pass through). The nulls help the story: the price surge looks like brand strategy, not demand from the rich or the cost of gold.

## Mix test: is the mix effect just quartz collapsing?

I reran the decomposition on subsets of tariff lines (same method as `02_Price:Volume:Decomposition.R`). Cumulative log changes, 2012–2025:

| Sample | Value | Volume | Price | Mix |
| --- | --- | --- | --- | --- |
| All lines | +0.19 | −0.69 | +0.63 | +0.25 |
| Without steel quartz | +0.28 | −0.28 | +0.66 | −0.09 |
| Mechanical only | +0.31 | −0.28 | +0.67 | −0.08 |

- Mix is entirely the cheap end shrinking. Without steel quartz it goes from +0.25 to −0.09. Among the remaining watches the mix moved slightly down-market: steel mechanical's share of value rose from 44% to 52%, while precious stayed at about 39%.
- Price doesn't depend on quartz. It's about +0.65 in every sample. Unit values roughly doubled within lines: precious mechanical CHF 14,800 to 29,100, steel mechanical 1,370 to 2,560, steel quartz 160 to 244.
- Most of the volume drop is steel quartz: 12.8 of the 14.6 million fewer pieces since 2012. In logs, units fall 0.69 overall and 0.28 without it.
- Steel quartz is still 64% of pieces in 2025 (76% in 2012) but only 9% of value (18% in 2012). It shrank, it didn't disappear.

The "price" term is the change in unit value within each tariff line, and the lines are broad (9102.21 covers a CHF 500 automatic and a CHF 15,000 steel Rolex). So it's price hikes plus upgrading within a line, and the data can't separate the two. Don't call it "same-watch" prices.

What I can write: Swiss watch exports shifted toward expensive categories only because cheap quartz collapsed. Within every category, unit values roughly doubled, through price hikes, upgrading, or both, and that is what carried export value.

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
| 1. Intro | `figures/value_vs_units.png` | Value is about 2.6× its 2000 level while units are down by half (29.7 to 14.6 million). Cover candidate |
| 2. Facts | `figures/tier_composition.png` | Over-3,000 band goes from a third to 80% of value |
| | `figures/mechanical_watch_share.png` | Mechanical is 86% of value but only about 36% of units |
| | `figures/top_destinations.png` | HK collapses (4.1 to 1.7bn CHF), the US doubles, JP, GB and SG grow |
| | `tables/growth_by_tier.csv` (T1) | 2019–25: precious value +33–38% while units fall; steel quartz units −30% |
| 3. Decomposition | `figures/decomposition_waterfall.png` | The headline: −0.69 volume, +0.63 price, +0.25 mix = +0.19 total |
| | `figures/price_index_vs_cpi.png` | Within-category unit values far outrun inflation and speed up after 2019 |
| | Mix test (in text or a small table) | Mix effect disappears without steel quartz; price effect doesn't |
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
