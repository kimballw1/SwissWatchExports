
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
# All four are year-over-year log changes
# value_change:  change in total export value
# volume_effect: part from shipping more or fewer watches
# price_effect:  part from the same kind of watch costing more
# mix_effect:    part from shifting toward pricier or cheaper kinds of watch
# value_change = volume_effect + price_effect + mix_effectth
decomp <- year_totals |>
  left_join(price_term, by = "year") |>
  mutate(mix = dlog_avg_price - price) |>
  filter(year > 2000) |>
  select(year, value_change = dlog_value, volume_effect = dlog_units, price_effect = price, mix_effect = mix)

write_csv(decomp, here("output/tables", "decomposition_annual.csv"))

decomp



#VISUALS

#plotting the decomposition of value change into volume, price, and mix effects
decomp_chart <- decomp |> 
  pivot_longer(c(volume_effect, price_effect, mix_effect), names_to = "part", values_to = "change") |>
  mutate(
    part = factor(part, levels = c("volume_effect", "price_effect", "mix_effect"), labels = c("Volume", "Price", "Mix"))
    ) |>
  ggplot(aes(x = year, y = change)) +
  geom_col(aes(fill = part)) +
  geom_point(aes(y = value_change), size = 2) +
  geom_hline(yintercept = 0) +
  labs(
    x = "Year",
    y = "Log change from previous year",
    fill = NULL,
    title = "What Drove the Change in Swiss Watch Export Value",
    caption = "Bars: volume, price and mix. Dots: total change in export value."
  )

decomp_chart
ggsave(here("output/figures", "decomposition_by_year.png"), decomp_chart, width = 8, height = 5, dpi = 300)



#cumulative waterfall, 2012 to 2025
waterfall <- decomp |>
  filter(year >= 2013) |>
  summarize(
    Volume = sum(volume_effect),
    Price = sum(price_effect),
    Mix = sum(mix_effect)
  ) |>
  pivot_longer(everything(), names_to = "part", values_to = "change") |>
  mutate(
    end = cumsum(change),
    start = lag(end, default = 0)
  ) |>
  add_row(part = "Total", change = sum(decomp$value_change[decomp$year >= 2013]), start = 0, end = sum(decomp$value_change[decomp$year >= 2013])) |>
  mutate(
    part = factor(part, levels = part),
    position = as.numeric(part)
  )

waterfall_chart <- waterfall |>
  ggplot() +
  geom_rect(aes(xmin = position - 0.4, xmax = position + 0.4, ymin = start, ymax = end, fill = change > 0)) +
  geom_text(aes(x = position, y = pmax(start, end) + 0.04, label = sprintf("%+.2f", change))) +
  geom_hline(yintercept = 0) +
  scale_x_continuous(breaks = waterfall$position, labels = waterfall$part) +
  scale_fill_manual(values = c("TRUE" = "#2c7bb6", "FALSE" = "#d7191c"), guide = "none") +
  labs(
    x = NULL,
    y = "Cumulative log change, 2012-2025",
    title = "Swiss Watch Export Value, 2012-2025: Fewer Watches, Higher Prices"
  )

waterfall_chart
ggsave(here("output/figures", "decomposition_waterfall.png"), waterfall_chart, width = 7, height = 5, dpi = 300)


#chained price index vs Swiss CPI, 2000 = 100
cpi_annual <- read_csv(here("data/clean/clean_cpi_monthly.csv"), na = "") |>
  group_by(year = year(month)) |>
  summarize(cpi = mean(cpi)) |>
  filter(year <= 2025)

price_index <- decomp |>
  select(year, price_effect) |>
  add_row(year = 2000, price_effect = 0) |>
  arrange(year) |>
  mutate(watch_prices = 100 * exp(cumsum(price_effect))) |>
  left_join(cpi_annual, by = "year") |>
  mutate(swiss_cpi = cpi / cpi[year == 2000] * 100)

price_index_chart <- price_index |>
  pivot_longer(c(watch_prices, swiss_cpi), names_to = "series", values_to = "index") |>
  mutate(series = if_else(series == "watch_prices", "Swiss watch prices (same watch)", "Swiss CPI")) |>
  ggplot(aes(x = year, y = index, color = series)) +
  geom_line(linewidth = 1) +
  labs(
    x = "Year",
    y = "Index (2000 = 100)",
    color = NULL,
    title = "Swiss Watch Prices vs Swiss Consumer Prices"
  )

price_index_chart
ggsave(here("output/figures", "price_index_vs_cpi.png"), price_index_chart, width = 8, height = 5, dpi = 300)

