library(tidyverse)

## Input
# Path
path      	  <- ".../"
input     	  <- str_glue("{path}data/partial_matches__categorized_.tsv")
output        <- str_glue("{path}data/partial_matches__processed.tsv")
# Read
data_raw <- read_tsv(input, guess_max = 5000)		

## Processing_2
# At this moment, it is needed to only work with the isOK !=0 records, 1 - no such records, so is.na 
data <- data_raw |> filter(is.na(isOK)) |> select(-category, -isOK)

## Export to categorize further according to the way as exact matches had been treated
write_tsv(data, output)