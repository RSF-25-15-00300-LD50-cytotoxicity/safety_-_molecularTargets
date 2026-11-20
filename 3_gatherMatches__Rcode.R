library(tidyverse)

## Input
path      	  <- ".../"
input_p       <- str_glue("{path}data/partial_matches__processed.tsv")
input_e       <- str_glue("{path}data/exact_matches__processed.tsv")
output        <- str_glue("{path}data/matches__gathered.tsv")
e_matches     <- read_tsv(input_e) |> mutate(type = "exact")
p_matches     <- read_tsv(input_p) |> mutate(type = "partial")
# Bind
matches <- bind_rows(e_matches, p_matches) |> rename(math_biased = math, activity_biased = activity, route_biased = route)

## Summarize matches
matches_sum <- matches |> pivot_longer(cols = c(safety_biased, certainty_biased, cause_biased, math_biased, activity_biased, route_biased),
							names_to = "label", values_to = "value", values_drop_na = TRUE) |>
						  group_by(label) |>
						  summarize(n = n()) |>
						  arrange(desc(n))

## Export
write_tsv(matches, output)