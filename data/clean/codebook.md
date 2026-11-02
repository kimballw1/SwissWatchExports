# Codebook for data/clean

Everything here is made by `code/01_Clean.R` from the files in `data/raw`. Missing values are blank cells. Read with `read_csv(file, na = "")`.

## merged_data/panel_annual.csv
One row per country x tier x year. 22 countries, 4 tiers, 2000-2024 = 2,200 rows.

| Column | Meaning | Units | Source |
| --- | --- | --- | --- |
| iso2 | Destination country | 2-letter code | BAZG |
| tier | precious_mech, precious_quartz, steel_mech, steel_quartz | | tariff lines |
| year | Calendar year | | |
| exports_chf | Export value, summed over the year's months | CHF, nominal | BAZG |
| units | Watches exported | pieces | BAZG |
| unit_value | exports_chf / units | CHF per watch | computed |
| top1_income | Top 1% pre-tax income share (sptinc992j, p99p100) | share, 0-1 | WID |
| top1_wealth | Top 1% net wealth share (shweal992j, p99p100) | share, 0-1 | WID |
| gdp_const_usd | GDP (NY.GDP.MKTP.KD) | constant 2015 USD | WDI |
| gdp_pc_ppp | GDP per capita (NY.GDP.PCAP.PP.KD) | constant PPP dollars | WDI |
| equity_index | Annual average of the monthly stock index. Blank for AT, BE, BH, GR, PT, QA, SA (no index) and for AE in 2000-2013 (series starts May 2014; AE 2014 averages May-Dec) | 2015 = 100 | OECD via FRED; Yahoo for HK, SG, AE |
| chf_per_lcu | Annual average exchange rate | CHF per unit of local currency | FRED; pegs for AE, SA, QA, BH |
| rer | Real exchange rate: chf_per_lcu x destination CPI / Swiss CPI. Higher = destination currency stronger in real terms. Blank for AE 2000-2006 (no CPI) | index (CPIs 2010 = 100) | FRED + WDI FP.CPI.TOTL |
| quality_income | WID data quality flag for the income share | 0 (imputed) to 5 | WID |
| quality_wealth | WID data quality flag for the wealth share | 0 (imputed) to 5 | WID |

## merged_data/panel_monthly.csv
One row per country x tier x month. Core 15 countries, 4 tiers, Jan 2000-Sep 2026 (321 months). 19,247 rows: 13 cells have no exports and no row (CA precious_quartz April 2020, and 12 China cells in 2000-2002).

| Column | Meaning | Units | Source |
| --- | --- | --- | --- |
| iso2 | Destination country | 2-letter code | BAZG |
| tier | Watch tier | | |
| month | First day of the month | date | |
| exports_chf | Export value | CHF, nominal | BAZG |
| units | Watches exported | pieces | BAZG |
| equity_index | Monthly stock index. Blank for AE before May 2014 and for the 12 OECD countries in Sep 2026 | 2015 = 100 | OECD via FRED; Yahoo for HK, SG, AE |
| chf_per_lcu | Monthly average exchange rate | CHF per unit of local currency | FRED; peg for AE |
| gold_chf | Gold price | CHF per troy ounce | World Bank Pink Sheet x FRED EXSZUS |
| top1_income_2012 | The country's top 1% income share in 2012, same in every row | share, 0-1 | WID |
| anti_graft ... us_tariff_39 | Seven 0/1 shock dummies, same in every country (see clean_shocks_monthly.csv) | 0/1 | hand-coded |

## merged_data/panel_line.csv
One row per country x tariff line x month. All 242 destinations, 10 wristwatch lines (9101.12.00 only until 2006), Jan 2000-Sep 2026. 230,432 rows, the same rows as clean_watch_exports_monthly.csv. The wide 22 are 24% of rows and 85% of value.

| Column | Meaning | Units | Source |
| --- | --- | --- | --- |
| iso2 | Destination country | 2-letter code | BAZG |
| tariff_line | 8-digit tariff line, e.g. "9101.21.00" | text | BAZG |
| tier | precious_mech, precious_quartz, steel_mech, steel_quartz | | tariff lines |
| month | First day of the month | date | |
| units | Watches exported | pieces | BAZG |
| exports_chf | Export value | CHF, nominal | BAZG |
| unit_value | exports_chf / units | CHF per watch | computed |
| chf_per_lcu | Monthly exchange rate. Blank outside the wide 22 | CHF per unit of local currency | FRED; pegs for AE, SA, QA, BH |
| gold_chf | Gold price | CHF per troy ounce | World Bank Pink Sheet x FRED EXSZUS |
| anti_graft ... us_tariff_39 | Seven 0/1 shock dummies (see clean_shocks_monthly.csv) | 0/1 | hand-coded |

Months with no shipments have no row. Used for the decomposition (all countries), 3b (9102 lines, wide 22) and 3c (all lines, wide 22).

## merged_data/polarization_monthly.csv
One row per month, Jan 2000-Sep 2026 (321 rows). All destinations and all 9 wristwatch lines.

| Column | Meaning | Units |
| --- | --- | --- |
| month | First day of the month | date |
| exports_chf | Total wristwatch export value | CHF, nominal |
| exports_chf_over_3000 | Value from line x country cells with unit value over CHF 3,000 | CHF, nominal |
| polarization | exports_chf_over_3000 / exports_chf | share, 0-1 |

## Intermediate files
| File | One row is | Notes |
| --- | --- | --- |
| clean_watch_exports_monthly.csv | country x tariff line x month, Jan 2000-Sep 2026 | All countries, pocket watches dropped, 230,432 rows. Columns iso2, month, tariff_line ("9101.21.00"), tier, units, exports_chf, unit_value. Months with no shipments have no row. 2026 is provisional |
| clean_wid_top_shares.csv | country x year, 2000-2024 | iso2, year, top1_income, top1_wealth, quality_income, quality_wealth |
| clean_wdi_gdp.csv | country x year | iso2, year, gdp_const_usd, gdp_pc_ppp. Aggregates dropped |
| clean_wdi_cpi.csv | country x year, 2000-2025 | iso2, year, cpi (2010 = 100). Aggregates dropped |
| clean_equity_monthly.csv | country x month, 2000 to Sep 2026 | iso2, month, equity_index. 15 countries |
| clean_fx_monthly.csv | country x month, 2000 to Sep 2026 | iso2, month, currency, chf_per_lcu. 22 countries |
| clean_gold_monthly.csv | month, Jan 2000-Sep 2026 | month, gold_usd, gold_chf (per troy ounce) |
| clean_cpi_monthly.csv | month, Jan 2000-Sep 2026 | month, cpi (Swiss CPI, December 2020 = 100) |
| clean_shocks_monthly.csv | month, Jan 2000-Sep 2026 | 0/1 columns: anti_graft (Dec 2012 on), chf_unpeg (Jan 2015 on), apple_watch (May 2015 on), hk_protests (Jun-Dec 2019), covid (Mar 2020-Jun 2021), us_frontload (Apr 2025 and Jul 2025), us_tariff_39 (Aug-Nov 2025). The last two are US events; interact with a US dummy where it matters |
| clean_fh_price_tiers.csv | period x price band, world totals | year, month (blank for annual rows), band (total, under_200, 200_500, 500_3000, over_3000), units (pieces), exports_chf (CHF). Annual rows for 2000, 2005, 2010, 2015, 2020-2025; monthly rows Jan 2025-Aug 2026. 150 rows. Rounded in the PDF to 1,000 units and CHF 0.1m. Descriptives only |
