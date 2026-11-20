library(tidyverse)

## Input
# Path
path      	  <- ".../"
input     	  <- str_glue("{path}data/partial_matches__categorized.tsv")
output        <- str_glue("{path}data/partial_matches__categorized_.tsv")
# Read
data_raw <- read_tsv(input, guess_max = 5000)		

## Processing_1
# At this moment, it is needed to only work with the isOK==1 records 
data <- data_raw |> filter(isOK == 1)

## Export to categorize further according to the way as exact matches had been treated
write_tsv(data, output)