# Codebook

All files are made by `code/Clean.R`. Blank cell = missing. Read with `read_csv(file, na = "")`.

**Tiers:** precious_mech, precious_quartz, steel_mech, steel_quartz (precious = gold/platinum case, steel = everything else).
**Samples:** core 15 = HK US CN JP SG GB DE IT AE FR KR ES AU NL CA. Wide 22 = core 15 + AT BE PT GR SA QA BH.

## Analysis panels (merged_data/)

### panel_annual.csv
Country × tier × year. Wide 22, 2000-2024.

| Column | Meaning |
| --- | --- |
| iso2, tier, year | Keys |
| exports_chf | Export value (CHF) |
| units | Watches exported |
| unit_value | exports_chf / units |
| top1_income | Top 1% income share (0-1) |
| top1_wealth | Top 1% wealth share (0-1) |
| gdp_const_usd | GDP (constant USD) |
| gdp_pc_ppp | GDP per capita (PPP) |
| equity_index | Stock index (2015 = 100). Blank for 7 countries without one |
| chf_per_lcu | CHF per unit of local currency |
| rer | Real exchange rate (higher = destination currency stronger) |
| quality_income, quality_wealth | WID data quality (0 = imputed) |

### panel_monthly.csv
Country × tier × month. Core 15, Jan 2000-Sep 2026.

| Column | Meaning |
| --- | --- |
| iso2, tier, month | Keys |
| exports_chf, units | Export value (CHF), watches exported |
| equity_index | Stock index (2015 = 100) |
| chf_per_lcu | CHF per unit of local currency |
| gold_chf | Gold price (CHF per ounce) |
| top1_income_2012 | Country's 2012 top 1% income share |
| anti_graft ... us_tariff_39 | Shock dummies (0/1), see below |

### panel_line.csv
Country × tariff line × month. All countries, Jan 2000-Sep 2026.

| Column | Meaning |
| --- | --- |
| iso2, tariff_line, month | Keys (tariff_line like "9101.21.00") |
| tier | Tier of the tariff line |
| units, exports_chf, unit_value | Watches, export value (CHF), CHF per watch |
| chf_per_lcu | CHF per unit of local currency. Blank outside the wide 22 |
| gold_chf | Gold price (CHF per ounce) |
| anti_graft ... us_tariff_39 | Shock dummies (0/1), see below |

### polarization_monthly.csv
One row per month.

| Column | Meaning |
| --- | --- |
| month | Month |
| exports_chf | Total export value (CHF) |
| exports_chf_over_3000 | Value from cells with unit value over CHF 3,000 |
| polarization | Share of value over CHF 3,000 (0-1) |

## Source files

| File | One row is | Columns |
| --- | --- | --- |
| clean_watch_exports_monthly.csv | country × tariff line × month | iso2, month, tariff_line, tier, units, exports_chf, unit_value |
| clean_wid_top_shares.csv | country × year | iso2, year, top1_income, top1_wealth, quality_income, quality_wealth |
| clean_wdi_gdp.csv | country × year | iso2, year, gdp_const_usd, gdp_pc_ppp |
| clean_wdi_cpi.csv | country × year | iso2, year, cpi (2010 = 100) |
| clean_equity_monthly.csv | country × month | iso2, month, equity_index |
| clean_fx_monthly.csv | country × month | iso2, month, currency, chf_per_lcu |
| clean_gold_monthly.csv | month | month, gold_usd, gold_chf |
| clean_cpi_monthly.csv | month | month, cpi (Swiss, Dec 2020 = 100) |
| clean_shocks_monthly.csv | month | month + the 7 shock dummies |
| clean_fh_price_tiers.csv | year (or month) × price band | year, month, band, units, exports_chf (world totals, descriptives only) |

## Shock dummies

| Dummy | Equals 1 |
| --- | --- |
| anti_graft | Dec 2012 on |
| chf_unpeg | Jan 2015 on |
| apple_watch | May 2015 on |
| hk_protests | Jun-Dec 2019 |
| covid | Mar 2020-Jun 2021 |
| us_frontload | Apr 2025, Jul 2025 |
| us_tariff_39 | Aug-Nov 2025 |
