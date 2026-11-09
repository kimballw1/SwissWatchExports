library(tidyverse)
library(lubridate)
library(janitor)
library(countrycode)
library(readxl)
library(pdftools)
library(here)

# ---- Loading the data -----

# country x tariff line x month exports; everything else gets joined onto this
# tariff numbers kept as text, otherwise "9101.2100" reads as 9101.21
bazg_watch_exports_monthly <- read_delim(here("data/raw", "bazg_watch_exports_monthly.csv"), delim = ";", na = "", col_types = cols(Tariffnumber8 = "c"))

# -- panel_annual only --
wdi_gdp <- read_csv(here("data/raw", "wdi_gdp.csv"), na = "")
wdi_cpi <- read_csv(here("data/raw", "wdi_cpi.csv"), na = "", skip = 4)   # for the real exchange rate

# -- panel_annual + panel_monthly --
# monthly needs only the 2012 top 1% income share from WID
wid_top_shares <- read_csv(here("data/raw", "wid_top_shares.csv"), na = "") #world ineqaulity database income dist
fred_exchange_rates_monthly <- read_csv(here("data/raw", "fred_exchange_rates_monthly.csv"), na = "")
oecd_share_prices_monthly <- read_csv(here("data/raw", "oecd_share_prices_monthly.csv"), na = "")
yahoo_share_prices_hk_sg_ae_monthly <- read_csv(here("data/raw", "yahoo_share_prices_hk_sg_ae_monthly.csv"), na = "") # HK, SG, UAE stock indices

# -- gold (panel_monthly) and Swiss CPI (price index) --
worldbank_commodity_prices_monthly <- read_excel(here("data/raw", "worldbank_commodity_prices_monthly.xlsx"), sheet = "Monthly Prices", skip = 4)
fso_cpi_monthly <- read_excel(here("data/raw", "fso_cpi_monthly.xlsx"), sheet = "LIK_multibasis_m", skip = 3)

# -- descriptives only --
fh_exports_by_price <- pdf_text(here("data/raw", "fh_exports_by_price.pdf"))


# ---- Swiss exports -----

exports_clean <- bazg_watch_exports_monthly |>
  clean_names() |>
  rename(iso2 = country_iso_alpha2, tariff_line = tariffnumber8) |>
  filter(year >= 2000) |>
  mutate(month = make_date(year, month)) |>
  filter(!tariff_line %in% c("9101.9100", "9101.9900", "9102.9100", "9102.9900")) |>   # drop pocket watches
  mutate(tier = case_when(
    tariff_line %in% c("9101.2100", "9101.2900") ~ "precious_mech",
    tariff_line %in% c("9101.1100", "9101.1200", "9101.1900") ~ "precious_quartz",   # 9101.1200 ends in 2006
    tariff_line %in% c("9102.2100", "9102.2900") ~ "steel_mech",
    tariff_line %in% c("9102.1100", "9102.1200", "9102.1900") ~ "steel_quartz"
  )) |>
  select(iso2, month, tariff_line, tier, units = supplementary_quantity, exports_chf = value_chf) |>
  # "9101.2100" -> "9101.21.00": with two dots read_csv keeps it as text,
  # with one dot it reads it back as the number 9101.21
  mutate(tariff_line = paste0(substr(tariff_line, 1, 7), ".", substr(tariff_line, 8, 9))) |>
  # average export price per watch (CHF) for this country x line x month
  mutate(unit_value = exports_chf / units)

write_csv(exports_clean, here("data/clean", "clean_watch_exports_monthly.csv"), na = "")


# ---- FH price tiers -----

# world totals by export price band: annual rows for selected years, monthly rows from Jan 2025
fh_price_tiers <- tibble(line = str_squish(unlist(str_split(fh_exports_by_price, "\n")))) |>
  filter(str_detect(line, "^(\\d{4}|[A-Z][a-z]{2} \\d{2}) ")) |>   # data rows start with "2000" or "Jan 25"
  mutate(period = str_extract(line, "^(\\d{4}|[A-Z][a-z]{2} \\d{2})")) |>
  mutate(values = str_squish(str_remove(line, period))) |>
  separate_wider_delim(values, delim = " ", names = c(
    "total_units", "total_chf", "under_200_units", "under_200_chf", "200_500_units", "200_500_chf",
    "500_3000_units", "500_3000_chf", "over_3000_units", "over_3000_chf"
  )) |>
  pivot_longer(-c(line, period), names_to = c("band", ".value"), names_pattern = "(.*)_(units|chf)") |>
  mutate(year = parse_number(period)) |>
  mutate(year = if_else(year < 100, 2000 + year, year)) |>
  mutate(month = match(str_sub(period, 1, 3), month.abb)) |>   # blank for the annual rows
  mutate(units = parse_number(units) * 1000) |>                 # PDF reports thousands of units
  mutate(exports_chf = parse_number(chf) * 1e6) |>              # and millions of CHF
  select(year, month, band, units, exports_chf)

write_csv(fh_price_tiers, here("data/clean", "clean_fh_price_tiers.csv"), na = "")


# ---- Sample countries -----

core_15 <- c("HK", "US", "CN", "JP", "SG", "GB", "DE", "IT", "AE", "FR", "KR", "ES", "AU", "NL", "CA")
wide_22 <- c(core_15, "AT", "BE", "PT", "GR", "SA", "QA", "BH")


# ---- WID top shares -----

# one row per country x year, income and wealth shares side by side
wid_clean <- wid_top_shares |>
  filter(percentile == "p99p100") |>
  filter(variable %in% c("sptinc992j", "shweal992j")) |>
  filter(year >= 2000, year <= 2024) |>
  mutate(variable = case_when(
    variable == "sptinc992j" ~ "income",
    variable == "shweal992j" ~ "wealth"
  )) |>
  select(iso2 = country, year, variable, value, data_quality) |>
  pivot_wider(
    names_from = variable,
    values_from = c(value, data_quality)
  ) |>
  select(
    iso2, year,
    top1_income = value_income, # fraction
    top1_wealth = value_wealth, # fraction 
    quality_income = data_quality_income,   # WID quality flag, 0 = imputed, 5 = best
    quality_wealth = data_quality_wealth
  )

write_csv(wid_clean, here("data/clean", "clean_wid_top_shares.csv"), na = "")


# ---- WDI GDP -----

wdi_clean <- wdi_gdp |>
  filter(regionname != "Aggregates") |>
  # 3-letter to 2-letter codes; Kosovo (XKX) and Channel Islands (CHI) have no iso2 and drop out
  mutate(iso2 = countrycode(countrycode, origin = "iso3c", destination = "iso2c", warn = FALSE)) |>
  filter(!is.na(iso2)) |>
  select(iso2, year, gdp_const_usd = ny_gdp_mktp_kd, gdp_pc_ppp = ny_gdp_pcap_pp_kd)

write_csv(wdi_clean, here("data/clean", "clean_wdi_gdp.csv"), na = "")


# ---- WDI CPI -----

# wide file, one column per year
wdi_cpi_clean <- wdi_cpi |>
  select(countrycode = `Country Code`, starts_with("20")) |>
  pivot_longer(-countrycode, names_to = "year", values_to = "cpi") |>
  mutate(year = as.integer(year)) |>
  mutate(iso2 = countrycode(countrycode, origin = "iso3c", destination = "iso2c", warn = FALSE)) |>
  filter(!is.na(iso2)) |>
  select(iso2, year, cpi)

write_csv(wdi_cpi_clean, here("data/clean", "clean_wdi_cpi.csv"), na = "")


# ---- Stock indices -----

# both files are wide (one column per country), so make each long and stack them
oecd_long <- oecd_share_prices_monthly |>
  #stock market price index for each country containing most commonly listed companies typically averaged over the month
  pivot_longer(-Month, names_to = "country", values_to = "equity_index")

yahoo_long <- yahoo_share_prices_hk_sg_ae_monthly |>
  pivot_longer(-Month, names_to = "country", values_to = "equity_index")

equity_monthly <- bind_rows(oecd_long, yahoo_long) |>
  mutate(iso2 = countrycode(country, origin = "country.name", destination = "iso2c")) |>
  mutate(month = ym(Month)) |>
  filter(month >= ym("2000-01")) |>
  filter(month <= ym("2026-09")) |>     # drops the partial October 2026 row
  filter(!is.na(equity_index)) |>       # UAE before May 2014
  select(iso2, month, equity_index)

# annual average of the monthly index (UAE 2014 averages May-Dec only)
equity_annual <- equity_monthly |>
  mutate(year = year(month)) |>
  group_by(iso2, year) |>
  summarise(equity_index = mean(equity_index), .groups = "drop")

write_csv(equity_monthly, here("data/clean", "clean_equity_monthly.csv"), na = "")


# ---- Exchange rates -----

# FRED quotes most series as local currency per USD, but EUR, GBP and AUD as USD per unit.
# Turn everything into CHF per unit of local currency (chf_per_lcu)
fx_wide <- fred_exchange_rates_monthly |>
  mutate(month = floor_date(observation_date, "month")) |>
  filter(month >= ym("2000-01")) |>
  mutate(
    USD = EXSZUS,
    EUR = EXSZUS * EXUSEU,
    GBP = EXSZUS * EXUSUK,
    AUD = EXSZUS * EXUSAL,
    JPY = EXSZUS / EXJPUS,
    CNY = EXSZUS / EXCHUS,
    HKD = EXSZUS / EXHKUS,
    SGD = EXSZUS / EXSIUS,
    KRW = EXSZUS / EXKOUS,
    CAD = EXSZUS / EXCAUS,
    AED = EXSZUS / 3.6725,
    SAR = EXSZUS / 3.75,
    QAR = EXSZUS / 3.64,
    BHD = EXSZUS / 0.376
  ) |>
  select(month, USD, EUR, GBP, AUD, JPY, CNY, HKD, SGD, KRW, CAD, AED, SAR, QAR, BHD)

fx_long <- fx_wide |>
  pivot_longer(-month, names_to = "currency", values_to = "chf_per_lcu")

# which currency each sample country uses
currency_map <- tribble(
  ~iso2, ~currency,
  "US", "USD",
  "DE", "EUR", "FR", "EUR", "IT", "EUR", "ES", "EUR", "NL", "EUR",
  "AT", "EUR", "BE", "EUR", "PT", "EUR", "GR", "EUR",
  "GB", "GBP",
  "AU", "AUD",
  "JP", "JPY",
  "CN", "CNY",
  "HK", "HKD",
  "SG", "SGD",
  "KR", "KRW",
  "CA", "CAD",
  "AE", "AED",
  "SA", "SAR",
  "QA", "QAR",
  "BH", "BHD"
)

# many-to-many on purpose: one euro rate per month goes to all 9 euro countries
fx_monthly <- currency_map |>
  inner_join(fx_long, by = "currency", relationship = "many-to-many") |>
  select(iso2, month, currency, chf_per_lcu)

fx_annual <- fx_monthly |>
  mutate(year = year(month)) |>
  group_by(iso2, year) |>
  summarise(chf_per_lcu = mean(chf_per_lcu), .groups = "drop")

write_csv(fx_monthly, here("data/clean", "clean_fx_monthly.csv"), na = "")


# ---- Gold -----

# World Bank price is USD per troy ounce; convert with the CHF per USD rate
gold_monthly <- worldbank_commodity_prices_monthly |>
  select(month = 1, gold_usd = Gold) |>
  filter(!is.na(month)) |>   # drops the units row
  mutate(month = ym(month)) |>
  mutate(gold_usd = as.numeric(gold_usd)) |>
  filter(month >= ym("2000-01")) |>
  inner_join(select(fx_wide, month, USD), by = "month") |>
  mutate(gold_chf = gold_usd * USD) |>
  select(month, gold_usd, gold_chf)

write_csv(gold_monthly, here("data/clean", "clean_gold_monthly.csv"), na = "")


# ---- Swiss CPI -----

# one column per index base, named by its Excel date; 44166 = December 2020 = 100
cpi_monthly <- fso_cpi_monthly |>
  select(month = 1, cpi = `44166`) |>
  mutate(month = as_date(month)) |>
  filter(month >= ym("2000-01")) |>
  filter(!is.na(cpi))   # months not published yet

write_csv(cpi_monthly, here("data/clean", "clean_cpi_monthly.csv"), na = "")


# ---- Shock dates -----

# first and last month each shock is on; no end = stays on
shock_dates <- tribble(
  ~shock,         ~start,    ~end,
  "anti_graft",   "2012-12", NA,
  "chf_unpeg",    "2015-01", NA,
  "apple_watch",  "2015-05", NA,          # launched Apr 24, first full month
  "hk_protests",  "2019-06", "2019-12",
  "covid",        "2020-03", "2021-06",
  "us_frontload", "2025-04", "2025-04",   # US export spikes ahead of tariffs
  "us_frontload", "2025-07", "2025-07",
  "us_tariff_39", "2025-08", "2025-11"    # 39% US tariff on Swiss goods
) |>
  mutate(start = ym(start), end = ym(end)) |>
  mutate(end = coalesce(end, max(exports_clean$month)))

# one row per month, one 0/1 column per shock
shocks_monthly <- tibble(month = seq(ym("2000-01"), max(exports_clean$month), by = "month")) |>
  cross_join(shock_dates) |>
  mutate(on = as.integer(month >= start & month <= end)) |>
  group_by(month, shock) |>
  summarise(on = max(on), .groups = "drop") |>
  pivot_wider(names_from = shock, values_from = on)

write_csv(shocks_monthly, here("data/clean", "clean_shocks_monthly.csv"), na = "")


# ---- panel_annual.csv -----

cpi_ch <- wdi_cpi_clean |>
  filter(iso2 == "CH") |>
  select(year, cpi_ch = cpi)

panel_annual <- exports_clean |>
  filter(iso2 %in% wide_22) |>
  mutate(year = year(month)) |>
  filter(year >= 2000, year <= 2024) |>
  group_by(iso2, tier, year) |>
  summarise(
    exports_chf = sum(exports_chf),
    units = sum(units),
    .groups = "drop"
  ) |>
  # recomputed from the sums, not averaged from the monthly rows
  mutate(unit_value = exports_chf / units) |>
  left_join(wid_clean, by = c("iso2", "year")) |>
  left_join(wdi_clean, by = c("iso2", "year")) |>
  left_join(equity_annual, by = c("iso2", "year")) |>   # blank for the 7 countries without an index
  left_join(fx_annual, by = c("iso2", "year")) |>
  left_join(wdi_cpi_clean, by = c("iso2", "year")) |>
  left_join(cpi_ch, by = "year") |>
  # real exchange rate: nominal rate x destination prices / Swiss prices (blank for AE before 2007)
  mutate(rer = chf_per_lcu * cpi / cpi_ch) |>
  select(
    iso2, tier, year, exports_chf, units, unit_value,
    top1_income, top1_wealth, gdp_const_usd, gdp_pc_ppp,
    equity_index, chf_per_lcu, rer, quality_income, quality_wealth
  ) |>
  arrange(iso2, tier, year)

write_csv(panel_annual, here("data/clean/merged_data", "panel_annual.csv"), na = "")


# ---- panel_monthly.csv -----

# each country's top 1% income share in 2012, the starting concentration
top1_2012 <- wid_clean |>
  filter(year == 2012) |>
  select(iso2, top1_income_2012 = top1_income)

# country-tier-months with nothing shipped have no row (13: CA precious_quartz April 2020, 12 China cells in 2000-2002)
panel_monthly <- exports_clean |>
  filter(iso2 %in% core_15) |>
  group_by(iso2, tier, month) |>
  summarise(
    exports_chf = sum(exports_chf),
    units = sum(units),
    .groups = "drop"
  ) |>
  left_join(equity_monthly, by = c("iso2", "month")) |>   # UAE blank before May 2014, OECD countries blank Sep 2026
  left_join(select(fx_monthly, iso2, month, chf_per_lcu), by = c("iso2", "month")) |>
  left_join(top1_2012, by = "iso2") |>
  left_join(gold_monthly, by = "month") |>
  left_join(shocks_monthly, by = "month") |>
  select(iso2, tier, month, exports_chf, units, equity_index, chf_per_lcu, gold_chf, top1_income_2012, anti_graft:us_tariff_39) |>
  arrange(iso2, tier, month)

write_csv(panel_monthly, here("data/clean/merged_data", "panel_monthly.csv"), na = "")


# ---- panel_line.csv -----

# every country kept for the decomposition; FX only exists for the wide 22
panel_line <- exports_clean |>
  left_join(select(fx_monthly, iso2, month, chf_per_lcu), by = c("iso2", "month")) |>
  left_join(gold_monthly, by = "month") |>
  left_join(shocks_monthly, by = "month") |>
  select(iso2, tariff_line, tier, month, units, exports_chf, unit_value, chf_per_lcu, gold_chf, anti_graft:us_tariff_39) |>
  arrange(iso2, tariff_line, month)

write_csv(panel_line, here("data/clean/merged_data", "panel_line.csv"), na = "")


# ---- polarization_monthly.csv -----

# share of export value from country x line x month cells averaging over CHF 3,000 a watch (FH's top band, nominal)
polarization_monthly <- exports_clean |>
  group_by(month) |>
  summarise(
    exports_chf_over_3000 = sum(exports_chf[unit_value > 3000]),
    exports_chf = sum(exports_chf)
  ) |>
  mutate(polarization = exports_chf_over_3000 / exports_chf) |>
  select(month, exports_chf, exports_chf_over_3000, polarization)

write_csv(polarization_monthly, here("data/clean/merged_data", "polarization_monthly.csv"), na = "")
