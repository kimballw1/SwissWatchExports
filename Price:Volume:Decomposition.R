
library(pacman)
p_load(tidyverse, here)


panel_line <- read_csv(here("data/clean/merged_data/panel_line.csv"), na = "")


#Table of tariff line by year
lineyear <- panel_line |> 
  mutate(year = year(month)) |> 
  filter(year < 2026) |> 
  group_by(year, tariff_line) |> 
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  )



#Table containing the year totals and the log change in value, pieces, and average price
yeartotals <- panel_line |> 
  mutate(year = year(month)) |> 
  filter(year < 2026) |> 
  group_by(year) |> 
  summarize(
    exports_chf = sum(exports_chf),
    units = sum(units)
  ) |> 
  mutate(average_price = exports_chf/units) |> 
  arrange(year) |> 
  mutate(
    dlog_value = log(exports_chf) - lag(log(exports_chf)),
    dlog_pieces = log(units) - lag(log(units)),
    dlog_average_price = log(average_price) - lag(log(average_price))
    )
  
head(yeartotals, 20)
  

#
