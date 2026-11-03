library(tidyverse)
library(here)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")


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



teir_composition <- panel_line |> 
  group_by(year = year(month), tier) |>
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |> 
  filter(year <= 2025) |>
  ggplot(aes(x = year, y = exports_chf, fill = tier)) +
  geom_area(position = "fill") +
  labs(x = "Year", 
       y = "Share of export value (%)",
       title = "Composition of Exports by Tier"
       )

teir_composition #calling table
ggsave(here("output/figures", "tier_composition.png"), teir_composition, width = 8, height = 5, dpi = 300)
  
