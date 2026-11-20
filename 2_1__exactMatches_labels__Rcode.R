library(tidyverse)

## Input
# Path
path      	  <- ".../"
input     	  <- str_glue("{path}data/exact_matches__categorized.tsv")
output        <- str_glue("{path}data/exact_matches__processed.tsv")
# Read
data_raw <- read_tsv(input, skip = 1)				

## Processing
# The idea is as follows: manually labeling such a large dataset is hard task, the process is erroro prone,
# The more distinct labels - the more errors, rigorous rules for decision making and rigorous control are needed
# Thus, the results of such labeling as it was conducted are not suitable to be used as semantical descriptors alone
# However, in my opinion the simplier labeling system is viable addition to the list of ontologies, describing distinct biomedical topics;
# So, the idea behind the simplifications is:
# Delete terms, which were not lableled somehow manually
# Use rare labels (safety_biased, certainty_biased and cause_biased), since they are rare and if such a label was assigned:
# it is possible to verify it quite fast (false negatives are inevitable);
# analyze labels assigned freely from comment section and use those, which seem to be important.
comments <- data_raw |> select(cmnt) |>
						group_by(cmnt) |>
						summarize(n = n()) |>
						arrange(desc(n))
# quality  -> do not count this label as useful for the task -> change to NA
# geo      -> do not count this label as useful for the task -> change to NA
# unknown  -> do not count this label as useful for the task -> change to NA
# position  -> do not count this label as useful for the task -> change to NA
# activity -> important
# math     -> important
# route    -> important
# number   -> do not count this label as useful for the task -> change to NA
# time     -> important
# amount   -> do not count this label as useful for the task -> change to NA
# rank     -> important
# season   -> do not count this label as useful for the task -> change to NA
# anatomy  -> do not count this label as useful for the task -> change to NA
# procedure -> do not count this label as useful for the task -> change to NA
# imp      -> mostly covered by other labels
# part     -> to NA
# part of  -> to NA
# publishing -> to NA
# ai       -> to NA
# celebration -> to NA
# complex -> to NA
# education -> to NA
# info -> to NA
# language -> to NA
# length -> to NA
# measurement -> to NA
# paradox -> to NA
# phenomen -> to NA
# property -> to NA
# status -> to NA
# this -> to NA
# unmet -> to NA
# without -> to NA
data <- data_raw |> mutate(cmnt = if_else(cmnt %in% c("quality", "geo", "unknown", "position", "number",
								"time", "amount", "rank", "season", "anatomy", "procedure", "imp", "part", "part of",
								"publishing", "ai", "celebration", "complex", "education", "info", "language",
								"length", "measurement", "paradox", "phenomen", "property", "status", "this",
								"unmet", "without"), NA, cmnt)) |>
						mutate(is_ok = if_else(any(!is.na(entity_biased), !is.na(action_biased), !is.na(process_biased), !is.na(safety_biased), !is.na(certainty_biased), !is.na(cause_biased), !is.na(cmnt)), 1, 0)) |>
						filter(is_ok == 1) |>
						select(n, ids, labels, exact_from_title, length, safety_biased, certainty_biased, cause_biased, cmnt) |>
						pivot_wider(names_from = "cmnt", values_from = "cmnt") |>
						select(-`NA`, -length) |>
						mutate_at(vars(math, activity, route), ~if_else(is.na(.), NA, 1))

## Export
write_tsv(data, output)