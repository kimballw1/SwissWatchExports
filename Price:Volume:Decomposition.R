
library(pacman)
p_load(tidyverse, here)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")

lineyear <- panel_line |> 
  mutate(year = year(month)) |> 
  filter(year < 2026) |> 
  group_by(year, tariff_line) |> 
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  )

lineyear