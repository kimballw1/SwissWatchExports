library(tidyverse)
library(here)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")
fh_tiers <- read_csv(here("data/clean/clean_fh_price_tiers.csv"), na = "")
polarization <- read_csv(here("data/clean/merged_data/polarization_monthly.csv"), na = "")


# Value vs. Unit Chart
value_units <- panel_line |>
  group_by(year = year(month)) |> 
  filter(year <= 2025) |>
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |>
  mutate( #Adjusting the index's to account for the different unit scales in put them in ratios to graph
    value_index = exports_chf / exports_chf[year == 2000] * 100, 
    units_index = units / units[year == 2000] * 100
  ) |>
  pivot_longer(c(value_index, units_index), names_to = "series", values_to = "index") |>
  ggplot(aes(x = year, y = index, color = series)) +
  geom_line() +
  labs(
    x = "Year",
    y = "Index (2000 = 100)",
    caption = "Value vs. Unit Chart"
  )

value_units #calling table
ggsave(here("output/figures", "value_vs_units.png"), value_units, width = 8, height = 5, dpi = 300)


# Tier composition chart (FH price bands)
tier_composition <- fh_tiers |>
  filter(is.na(month), band != "total") |>
  ggplot(aes(x = factor(year), y = exports_chf, fill = band)) +
  geom_col(position = "fill") +
  labs(
    x = "Year",
    y = "Share of export value",
    title = "Composition of Exports by Price Band"
  )

tier_composition
ggsave(here("output/figures", "tier_composition.png"), tier_composition, width = 8, height = 5, dpi = 300)


#Unit value ridge line chart
unitvalue_ridgeline <- panel_line |> 
  mutate(year = year(month)) |> 
  mutate(log_uv = log(unit_value)) |> 
  ggplot(aes(x = log_uv, y = factor(year))) +
  ggridges::geom_density_ridges(stat = "density", aes(weight = units, height = after_stat(density))) + 
  labs(
    x = "Log(Unit Value)",
    y = "Year",
    title = "Distribution of Log(Unit Value) by Year"
  )

unitvalue_ridgeline #calling table
ggsave(here("output/figures", "unitvalue_ridgeline.png"), unitvalue_ridgeline, width = 8, height = 5, dpi = 300)


#Plotting how mechanical watches have changed
mech_plot <- panel_line |> 
  mutate(year = year(month)) |>
  mutate(mech = str_detect(tier, "mech")) |>
  group_by(year = year(month)) |> 
  filter(year <= 2025) |> 
  summarize(
    mech_exports = sum(exports_chf[mech]),
    mech_units = sum(units[mech]),
    exports = sum(exports_chf),
    units = sum(units)
  ) |>
  mutate(
    mech_exports_share = mech_exports / exports * 100,
    mech_units_share = mech_units / units * 100
  ) |>
  pivot_longer(c(mech_exports_share, mech_units_share), names_to = "series", values_to = "share") |>
  ggplot(aes(x = year, y = share, color = series)) + 
  geom_line() +
  labs(
    x = "Year",
    y = "Share of Mechanical Watches (%)",
    title = "Share of Mechanical Watches in Exports"
  )

mech_plot
ggsave(here("output/figures", "mechanical_watch_share.png"), mech_plot, width = 8, height = 5, dpi = 300)


# Top destinations, 2012 vs 2025
top_destinations <- panel_line |>
  filter(year(month) %in% c(2012, 2025)) |>
  group_by(year = year(month), iso2) |>
  summarize(exports_chf = sum(exports_chf) / 1e9) |>
  filter(iso2 %in% c("US", "JP", "CN", "HK", "GB", "SG", "AE", "FR", "DE", "IT")) |>
  ggplot(aes(x = reorder(iso2, exports_chf), 
             y = exports_chf, 
             fill = factor(year))
  ) +
  geom_col(position = "dodge") +
  coord_flip() +
  labs(x = "Destination", 
       y = "Export value (CHF billions)", 
       fill = "Year", 
       title = "Top Destinations, 2012 vs 2025"
  )

top_destinations
ggsave(here("output/figures", "top_destinations.png"), top_destinations, width = 8, height = 5, dpi = 300)

       
# Polarization index
polarization_plot <- polarization |>
  ggplot(aes(x = month, 
             y = polarization)
         ) +
  geom_line() +
  labs(x = "Month", 
       y = "Share of export value over CHF 3,000", 
       title = "Polarization Index")

polarization_plot
ggsave(here("output/figures", "polarization_index.png"), polarization_plot, width = 8, height = 5, dpi = 300)

# Growth rates by tier and period
growth_table <- panel_line |>
  group_by(year = year(month), tier) |>
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |>
  filter(year %in% c(2012, 2019, 2025)) |>
  group_by(tier) |>
  mutate(
    period = paste(lag(year), year, sep = "-"),
    value_growth = (exports_chf / lag(exports_chf) - 1) * 100,
    units_growth = (units / lag(units) - 1) * 100
  ) |>
  filter(year != 2012) |>
  select(tier, period, value_growth, units_growth)

growth_table
write_csv(growth_table, here("output/tables", "growth_by_tier.csv"))
