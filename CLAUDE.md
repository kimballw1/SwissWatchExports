# ECON 423: Fewer, Pricier, Richer (Swiss watch exports)

Full plan: see PLAN.md (exported from the project doc, Nov 1 2026). This file holds the decisions and data facts needed to write code, including where the disk differs from the plan.

## Research question
The Swiss watch industry ships far fewer watches than 15 years ago and earns more doing it. Three acts:
- What happened: price / volume / mix decomposition (RQ1), destination shifts and the rise of mechanical (RQ2).
- Why: top-end wealth and the top tier (RQ3), smartwatches and cheap quartz after April 2015 (RQ4), gold pass-through to precious-metal watch prices (RQ5).
- What next: forecasts by tier and destination, and whether wealth and gold predictors help the top tier most (RQ6).

## Repo
Git repo at ~/Downloads/Econ423_Project, remote github.com/kimballw1/Econ423_Project. All paths in code use here::here() relative to Econ423Project.Rproj, so the script runs from wherever the repo sits.

## Folder layout (actual)
```
data/raw/              downloads, never edited by hand
data/clean/            one tidy file per source
data/clean/merged_data/  panel_annual.csv, panel_monthly.csv, panel_line.csv, polarization_monthly.csv
code/01_Clean.R        cleaning + panel builds
output/                tables and figures
```
PLAN.md proposes R/00_setup.R through R/08_viz_sandbox.R and a separate 02_build.R. Not adopted yet: the panels are still built at the end of 01_Clean.R. Per-source clean files go in data/clean/, and the analysis panels they combine into go in data/clean/merged_data/. data/clean/codebook.md describes every output column.

R, tidyverse, lubridate, janitor, countrycode, readxl, pdftools (installed 2026-11-02), here::here() for paths. Analysis: fixest, modelsummary, fable/fabletools/tsibble/feasts, ggridges, ggbump, patchwork.

## Raw files (data/raw)
| File | Notes |
| --- | --- |
| bazg_watch_exports_monthly.csv | BAZG open data "Goods: Foreign trade by tariff number / country" (I14Y dataset BAZG_TARIFNR_LAND, export file TN8_EXP_en.zip, 690 MB zip / 10 GB csv, file dated 2026-10-20), downloaded 2026-11-02 and filtered to Tariffnumber4 9101 and 9102 while streaming; nothing else changed. Semicolon-delimited. Jan 1988-Sep 2026, 352,364 rows, 253 partners, all exports in Units. Columns: Traffic_direction, year, month, Tariffnumber8 ("9101.2100"), Tariffnumber8_txt, Tariffnumber4, Country_isoAlpha2, Country_txt, Supplementary_quantity (pieces), Quantity_kg, Value_CHF, Value_EUR, Value_USD, status (def / prov), plus quarter and text columns. Replaces the old Swiss-Impex dashboard pull (2012-2026). |
| worldbank_commodity_prices_monthly.xlsx | World Bank Pink Sheet (CMO-Historical-Data-Monthly.xlsx, updated Oct 2 2026), downloaded 2026-11-02. Sheet "Monthly Prices": header rows 1-6 (row 5 = names, row 6 = units), first column dates like "1960M01". Gold is column 70, "Gold ($/troy oz)", Jan 1960-Sep 2026. |
| fso_cpi_monthly.xlsx | FSO "LIK, Totalindex auf allen Basen seit Einführung [LANGE REIHEN MULTIBASIS]" (statistik.admin.ch asset 36878078, observation period to Sep 30 2026), downloaded 2026-11-02. Sheet "LIK_multibasis_m": rows 1-4 are headers; column 1 is the month as an Excel date serial; columns 2-13 are the total index on 12 bases (row 4 holds each base date as a serial: Jun 1914 ... Dec 2020, Dec 2025); last two columns are m/m and y/y % changes. 01_Clean.R uses the Dec 2020 = 100 column (header 44166), which runs Dec 1982-Sep 2026. |
| wdi_cpi.csv | World Bank bulk download for FP.CPI.TOTL (API_FP.CPI.TOTL_DS2_en_csv_v2_253.csv from the zip, last updated 2026-10-08), downloaded 2026-11-02. Wide: 4 junk lines, then Country Name, Country Code, Indicator Name, Indicator Code, one column per year 1960-2025. 2010 = 100. Read with skip = 4. |
| wid_top_shares.csv | WID, raw long format: country (iso2), variable (sptinc992j / shweal992j), percentile (p99p100 / p99.9p100), year (1800-2024), value, age, pop, data_quality. |
| wdi_gdp.csv | countrycode (3-letter), countryname, regionname, year, ny_gdp_mktp_kd, ny_gdp_pcap_pp_kd, sp_pop_totl. Drop regionname == "Aggregates". |
| fred_exchange_rates_monthly.csv | Raw FRED dollar rates, 1971-01 to 2026-09: observation_date, EXSZUS (CHF per USD), EXUSEU (USD per EUR), EXJPUS, EXCHUS, EXHKUS, EXSIUS, EXUSUK (USD per GBP), EXKOUS, EXCAUS, EXUSAL (USD per AUD). EUR, GBP and AUD are quoted the other way round from the rest. No AED column: AED comes from the 3.6725 peg like SAR, QAR and BHD. |
| oecd_share_prices_monthly.csv | Month, then one column per country name (12 OECD countries). 2015 = 100. Starts 1955; keep 2000+. |
| yahoo_share_prices_hk_sg_ae_monthly.csv | Month, Hong Kong, Singapore, United Arab Emirates (UAE = iShares MSCI UAE ETF, from 2014-05). Drop partial 2026-10 row. |
| fh_exports_by_price.pdf | FH "Watches by price point" historical series (Sep 2026 edition). World totals only, units and CHF by band (<200, 200-500, 500-3,000, >3,000). Annual for 2000, 2005, 2010, 2015, 2020-2025; monthly only Jan 2025-Aug 2026. |

## To pull
- Exports from 2000, gold and Swiss CPI were pulled on 2026-11-02 (see Raw files).
- Gold goes to CHF with EXSZUS from the FRED file. Swiss CPI comes from FSO, not FRED: CHECPIALLMINMEI stops at Apr 2025.
- WDI CPI pulled 2026-11-02. Google Trends dropped (not needed).

## Where the disk differs from PLAN.md
- **No FH price tier x country data exists.** FH publishes price bands only as world totals (fh_exports_by_price.pdf). The monthly FH releases show bands as % changes in a chart, no levels, no countries. So every regression and forecast uses the tariff 2x2 tiers; FH bands are for headline descriptives only. This touches 3a (beta_k "3,000+ vs under 200"), F2, Module 4 targets and the hierarchy, and the polarization index.
- **The 2x2 is not a proxy for 3,000+.** 2025 value shares: precious_mech 34.0%, precious_quartz 5.1%, steel_mech 51.6%, steel_quartz 9.3%. Precious metal = 39% of value vs FH >3,000 = 80%. Unit shares: steel_quartz 63.6%, steel_mech 33.7%. 2025 totals match FH (CHF 24.4bn, 14.6m pieces).
- **Swiss CPI** source is FSO, not FRED (above).
- **3b event study pre-years:** with 2012-start data and base year 2014 there are 2 pre-period coefficients (2012, 2013), not 3. With the 2000 pull, 14.
- The plan says "about 10 lines": there are 9 wristwatch lines after dropping the 2 pocket-watch lines.

## Data facts
BAZG bulk file (checked 2026-11-02):
- Same data as the old Swiss-Impex pull. On Jan 2012-Aug 2026 for the old file's 11 lines, both have exactly 132,957 line x country x month rows with the same keys; values match in all but 15 cells, all in 2026 (revisions). Totals: CHF 312.31bn in both.
- 2000 wristwatches: CHF 9.28bn, 29.7m pieces, matching FH's 2000 row (9,276.5m, 29,656k). 2011: CHF 18.1bn, 29.8m pieces.
- The 8-digit codes are stable from Jan 1996 on. In 1988-1995 the same codes carry older wording ("battery or accumulator powered" vs "electrically operated"). 9101.1200 (precious, opto-electronic display) runs until Dec 2006 and then disappears. All other kept lines run continuously 2000-2026.
- 2000-2026 wristwatch rows: 230,432; no zero units or values. 2026 rows are status "prov" (provisional), everything earlier "def".
- No blank or malformed ISO2 codes from 2000 on.

Old Swiss-Impex file (2012-2026, checked 2026-10-11): 132,957 rows, all "Export" and "Units", 11 tariff lines (9 kept + 2 pocket-watch lines), 176 months, 226 partners all formatted "XX - Name", no aggregate rows. Namibia ("NA - Namibia") is in it. Clean file: 129,091 rows, no zero or missing units or values.

Missing cells = nothing shipped (no zero rows). Across the core 15 (2,640 line-months per line), 9101.19.00 is missing in 2,135, 9102.12.00 in 265, 9102.19.00 in 74, three other lines in 1 each. Logs drop these silently, which matters for 3b on ln pieces; fepois on levels is the robustness check.

WID for 2012-2024 in the 22 countries: QA and SA top 1% income shares are constant every year (0.244, 0.232), and JP and SG barely move. The wealth quality flag is 0 in every year for AU, SA, QA and BH as well as HK, SG, JP and AE.

## Decisions and assumptions
- Tiers (drop pocket watches 9101.9100, 9101.9900, 9102.9100, 9102.9900):
  - precious_mech: 9101.2100, 9101.2900
  - precious_quartz: 9101.1100, 9101.1200 (until 2006), 9101.1900
  - steel_mech: 9102.2100, 9102.2900
  - steel_quartz: 9102.1100, 9102.1200, 9102.1900
- Regressions and forecasts use these tariff tiers (FH tiers don't exist by country).
- Core 15 (monthly work): HK, US, CN, JP, SG, GB, DE, IT, AE, FR, KR, ES, AU, NL, CA. These are the countries with a monthly stock index.
- Wide 22 (annual wealth panel): core 15 + AT, BE, PT, GR, SA, QA, BH.
- Euro countries: DE, FR, IT, ES, NL, AT, BE, PT, GR. Dollar pegs: AED 3.6725, SAR 3.75, QAR 3.64, BHD 0.376 per USD.
- Main inequality measure: top 1% pre-tax income share (WID sptinc992j, p99p100, adults 20+, equal-split). Wealth share (shweal992j) is the robustness check, because WID wealth shares are imputed (quality 0) for HK, SG, JP, AE in every year.
- Equity x Top1 interaction (3a monthly) uses the 2012 top 1% income share, same value every month. 2012 is the first year of the export data. An earlier base year misses big shifts: Korea's top 1% share was 6.7% in 2000 and 17.0% in 2012, and the 2000 and 2012 shares correlate only 0.69 across the core 15. Robustness: 2011 and 2000.
- Standard errors clustered by country, with wild cluster bootstrap p-values (only 22 / 15 clusters).
- Sample starts Jan 2000. panel_annual runs 2000-2024 (WID ends 2024).
- 3b and 3c run on the wide 22 (the countries with FX). No extra FX pull.
- Forecast hierarchy: no new pulls. Rest of world = total minus the top 10, computed from the clean exports file (it already has every partner).
- Panels are written to data/clean/merged_data/.
- Shock dummies (clean_shocks_monthly.csv, also in panel_monthly). Permanent regime changes switch on and stay on: anti_graft Dec 2012, chf_unpeg Jan 2015, apple_watch May 2015 (first full month after the Apr 24 launch, same as the 3b post period). Episodes switch off: hk_protests Jun-Dec 2019, covid Mar 2020-Jun 2021, us_frontload Apr 2025 and Jul 2025 (US exports +154% and +48% YoY), us_tariff_39 Aug-Nov 2025 (US exports -24% to -57% YoY; back to +20% in Dec 2025). Windows set from the export data on 2026-11-02; HK fell 27-30% YoY in Jun, Oct and Nov 2019. No Google Trends.

### Exchange rate: real in the annual panel, nominal in the monthly panel (decided 2026-11-02)
- panel_annual has rer = chf_per_lcu x CPI_destination / CPI_Switzerland, from WDI FP.CPI.TOTL (2010 = 100, annual). Annual 3a uses ln(rer). chf_per_lcu stays in the panel for comparison.
- panel_monthly keeps the nominal chf_per_lcu. Monthly 3a, 3b, 3c and the forecasts use nominal FX.
- Why: a real rate is the right measure of how expensive a Swiss watch is for a foreign buyer, and over 25 years inflation gaps add up, especially for the dollar-pegged AE, SA, QA, BH and HK, whose nominal rates against CHF move together. Monthly CPIs would take several separate pulls, and WDI's annual CPI ends in 2024/2025, so a monthly real rate would be blank or made up for the 2025-26 months the forecasts care about. The monthly models use 12-month changes, where the inflation gap is a point or two against FX swings of 10-20%.
- Swiss CPI is common to every country in a year, so the tier x year fixed effects absorb it; only destination CPI changes the estimates.
- Gap: WDI has no UAE CPI before 2007, so rer is blank for AE 2000-2006 (28 rows). US and QA CPI end in 2024, which the panel's 2024 end makes harmless.

### Polarization index: value share above CHF 3,000 (decided 2026-11-02)
- polarization_monthly.csv: each month, the share of total export value (all countries, all 9 wristwatch lines) that comes from line x country x month cells whose unit value is over CHF 3,000.
- Why this version: it's FH's top price band applied to the data we have monthly. Against FH's own >3,000 value share at its 10 annual points it correlates 0.98, better than mechanical share (0.97, but flat at 86% since 2020) or precious-metal share (0.89; -0.04 over the 20 FH months).
- Assumptions to state in the paper:
  - Cell averages, not single watches. A cell averaging CHF 2,900 can hold some CHF 10,000 watches, and the reverse. That's why the level sits below FH's (25% to 57% over 2000-2025, against FH's 34% to 80%). Present it as tracking FH's band, not equal to it.
  - The CHF 3,000 cutoff is nominal, as in FH. Swiss CPI rose about 18% from 2000 to 2026, so a little of the rise is inflation.
  - Monthly values are noisier than annual ones (range 18% to 71% across months).

## Open decisions
- Due date and format (paper, presentation, or both).

## Expected checks
Results of the full run on 2026-11-02 (exports from 2000):
- clean exports: 230,432 rows, Jan 2000-Sep 2026, no missing tiers. 2012-2025 rows identical to the old Swiss-Impex based file.
- panel_annual: 2,200 rows (22 x 4 x 25), every country-tier-year present, no missing exports, top shares, GDP or FX. Equity blank in 756 rows: the 7 no-index countries plus AE 2000-2013.
- panel_monthly: 19,247 rows (15 x 4 x 321 minus 13 cells with nothing shipped: CA precious_quartz 2020-04 and 12 China cells in 2000-2002). Equity blank for AE before May 2014 and for the 12 OECD countries in Sep 2026. Gold has no gaps.
- gold and CPI: 321 months each, Jan 2000-Sep 2026.
- panel_annual rer: blank only for AE 2000-2006 (28 rows).
- panel_line: 230,432 rows (same rows as the clean exports file), 242 countries, no duplicate keys. FX blank exactly for countries outside the wide 22 (76% of rows, 15% of value). Gold and shock dummies have no gaps.
- polarization_monthly: 321 months. Annual shares 25.3% (2000), 38.8% (2010), 56.9% (2025).
- clean_fh_price_tiers: 150 rows (30 table rows x 5 bands). Bands sum to the total within PDF rounding (1,000 units, CHF 0.1m); the 12 months of 2025 sum to the 2025 annual row exactly. FH totals for 2000, 2010 and 2025 match the BAZG exports to rounding.
- Reading fso_cpi_monthly.xlsx gives one harmless warning (a source URL in the last row of the date column).

## Gotchas
- Read files with read_csv(file, na = ""): Namibia's ISO2 code is "NA".
- Write files with write_csv(..., na = ""). The default writes NA as the text "NA", which read_csv(na = "") then reads back as a string.
- BAZG exports: semicolon-delimited; read Tariffnumber8 as character or "9101.2100" becomes the number 9101.21. After clean_names(): country_iso_alpha2, tariffnumber8, year + month columns, supplementary_quantity, value_chf.
- In data/clean the tariff line is written "9101.21.00" (two dots) so read_csv keeps it as text. Raw file and the tier mapping above use "9101.2100".
- Swiss-Impex numbers are revised, not first prints (e.g. Mar 2024 wristwatches: FH first print CHF 1,904.9m / -15.9%, Swiss-Impex now 1,997.9m / -11.8%).
- Unit value is a cell average (line x country x month), not a per-watch price. Within-line composition shifts show up as "price" in 3c and in the Törnqvist term.

## Working style
I write the code myself. Claude explains, checks things against the data, and flags decisions that need my judgment. Don't write scripts or analysis code unless I ask for it, and no stopifnot() checks in my script (verify separately and report). Keep explanations short and direct.
