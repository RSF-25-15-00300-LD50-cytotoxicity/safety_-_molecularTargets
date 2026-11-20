library(tidyverse)

## Input & processing
path      	  <- ".../data/"
# Terms from ontologies, naming here is problematic
matches_to_ontologies <- read_tsv(str_glue("{path}only-titles_vs_ontologies.tsv")) |>
							rename(onto_term = labels, match = exact_from_title, ontology = ontologies)
# Labeled terms
matches <- read_tsv(str_glue("{path}matches__gathered.tsv")) |>
				rename(onto_term = labels, match = exact_from_title) |>
				separate_longer_delim(cols = c(onto_term, match), delim = " | ") |>
				inner_join(matches_to_ontologies, by = "match") |>
				select(id, ids, pos_s, pos_e, onto_term.x, match, type, ontology, safety_biased,
						certainty_biased, cause_biased, math_biased, activity_biased, route_biased) |>
				rename(onto_term = onto_term.x)

# Some basic summarization
onto_summary <- matches |> select(ontology) |> group_by(ontology) |> summarize(n = n()) |> arrange(desc(n))
txpo_summary <- matches |> filter(ontology == "txpo") |> select(onto_term) |> group_by(onto_term) |> summarize(n = n()) |> arrange(desc(n))

## Export
write_tsv(matches, str_glue("{path}labelsMapped_back.tsv"))