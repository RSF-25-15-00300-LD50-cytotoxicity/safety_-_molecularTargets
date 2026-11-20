library(tidyverse)

## Input
path      <- ".../"
# Terms from ontologies, naming here is problematic
titles_raw    <- read_tsv(str_glue("{path}titles_vs_ontologies.tsv")) |>
							rename(onto_term = labels, match = exact_from_title, ontology = ontologies)
ok_labels <- read_tsv(str_glue("{path}labelsMapped_back.tsv"))

## Process
# Prepare unique titles
titles_all <- titles_raw |> select(text) |>
							distinct()   |>
							separate_longer_delim(text, delim = " | ") |>
							mutate(text = str_trim(text)) |>
							mutate(del = if_else(text %in% (seq(1:30000) |> as.character()), 1, 0)) |>
							filter(del != 1) |>
							distinct()
# Get exact title for each match
titles_onto <- titles_raw |> rowwise() |>
				mutate(t_start = str_locate_all(str_sub(text, 1, pos_s), "^| \\| ") |> unlist() |> last() + 1) |>
				mutate(t_end = str_locate(str_sub(text, pos_e, -1), "$| \\| ")[2] + pos_e-4) |>
				ungroup() |>
				mutate(title = str_sub(text, t_start, t_end)) |>
				distinct() |>
				inner_join(ok_labels |> select(pos_s, pos_e, onto_term, match, safety_biased, certainty_biased, cause_biased, math_biased, route_biased) |> distinct(), by = c("pos_s", "pos_e", "onto_term", "match")) |>
				select(onto_term, match, title,safety_biased, certainty_biased, cause_biased, math_biased, route_biased, ontology) |>
				mutate_at(vars(safety_biased, certainty_biased, cause_biased, math_biased, route_biased), ~if_else(is.na(.), 0, 1)) |>
				pivot_wider(names_from = "ontology", values_from = "ontology", values_fill = 0, values_fn = length)
names(titles_onto) <- c("onto_term", "match", "title", "d__safety", "d__certainty", "d__cause",
						"d__math", "d__route", "d__ncit", "d__txpo", "d__chebi", "d__mondo", "d__cl", "d__bao",
						"d__mesh", "d__efo", "d__ncbitaxon", "d__bto", "d__exo", "d__mi", "d__chmo", "d__cmpo",
						"d__wikipathways", "d__upheno", "d__vo", "d__ms", "d__obi", "d__cdao", "d__oae", "d__xco",
						"d__vario", "d__aio", "d__bmont", "d__aeo", "d__ogms", "d__mod", "d__dron", "d__xlmod",
						"d__dideo", "d__symp", "d__clo", "d__mmo", "d__phipo")
# Describe titles
titles_described <- titles_onto |> select(-onto_term, -match) |> distinct() |>
						group_by(title) |>
						mutate_at(vars(-group_cols()), sum) |>
						ungroup() |>
						distinct() |>
						right_join(titles_all, by = c("title" = "text")) |>
						select(-del) |>
						mutate(across(starts_with('d__'), ~if_else(.>0,1,0)))

## Export
write_tsv(titles_described, str_glue("{path}titles_described.tsv"))