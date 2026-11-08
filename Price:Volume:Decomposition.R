
library(pacman)
p_load(tidyverse, here)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")


#Table of tariff line by year
line_year <- panel_line |>
  filter(year(month) <= 2025) |>
  group_by(year = year(month), tariff_line) |>
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |>
  ungroup()



#Table containing the year totals and the log change in value, pieces, and average price
year_totals <- line_year |>
  group_by(year) |>
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |>
  arrange(year) |>
  mutate(
    avg_price = exports_chf / units,
    dlog_value = log(exports_chf) - log(lag(exports_chf)),
    dlog_units = log(units) - log(lag(units)),
    dlog_avg_price = log(avg_price) - log(lag(avg_price))
  )
  

#Adding tariff line share of exports, value per unit in chf, change in log unit value, and average share of exports per tariff_line
line_changes <- line_year |>
  group_by(year) |>
  mutate(
    share = exports_chf / sum(exports_chf),
    unit_value = exports_chf / units
  ) |>
  group_by(tariff_line) |>
  arrange(year, .by_group = TRUE) |>
  mutate(
    dlog_unit_value = log(unit_value) - log(lag(unit_value)),
    avg_share = (share + lag(share)) / 2
  ) |>
  ungroup()


#takes each line’s price change, weights it by how much money that line accounts for, and adds them up within each year. 
#The result is the value-weighted average price change for that year.
price_term <- line_changes |>
  group_by(year) |>
  summarize(price = sum(avg_share * dlog_unit_value, na.rm = TRUE))

#Mix and final table
decomp <- year_totals |>
  left_join(price_term, by = "year") |>
  mutate(mix = dlog_avg_price - price) |>
  filter(year > 2000) |>
  select(year, value_change = dlog_value, volume_effect = dlog_units, price_effect = price, mix_effect = mix)

write_csv(decomp, here("output/tables", "decomposition_annual.csv"))

# All four are year-over-year log changes
# value_change:  change in total export value
# volume_effect: part from shipping more or fewer watches
# price_effect:  part from the same kind of watch costing more
# mix_effect:    part from shifting toward pricier or cheaper kinds of watch
# value_change = volume_effect + price_effect + mix_effectth
decomp

