library(tidyverse)
library(umap)
library(praznik)
library(mirt)

## Function to describe phrases
describe_phrase <- function(phrase) {
	phrase <- str_to_lower(phrase)
	p_vec  <- str_split(phrase, "") |> unlist()
	d_vec <- rep(NA, length(p_vec))
	for (i in seq(1:length(p_vec))) {
		lft  <- p_vec[i-1]
		cntr <- p_vec[i]
		rght <- p_vec[i+1]
		if (is_empty(lft)) {lft = ""}
		if (is.na(rght)) {rght = ""}
		d_vec[i] <- str_c(lft,cntr,rght, collapse = "")
	}
	d_str <- d_vec |> unique() |> sort() |> str_c(collapse = "\t")
	d_str
}

## Input
path      	  <- ".../"
input     	  <- str_glue("{path}data/matches_unique.tsv")
out_exact     <- str_glue("{path}data/exact_matches__categorized.tsv")
out_partial   <- str_glue("{path}data/partial_matches__categorized.tsv")
tags_raw      <- read_tsv(input)

## Process
# Find exact matches, the task here is to filter out terms, which are too general
# Find partial matches, the task here is to filter out questionable mathces and terms, which are too general
matches <- tags_raw |> mutate(n_char = nchar(labels)) |> 
					mutate(category = if_else(str_to_lower(labels) == str_to_lower(exact_from_title), "exact_match", "partial_match"))
# The results are
dens__label_length <- ggplot(matches, aes(x = n_char, fill = category)) +
							geom_density(alpha=0.5, color = "#800000ff") +
							scale_fill_manual(values = c("grey10", "grey90")) +
							scale_y_sqrt(limits = c(0, .1), breaks = c (.01, .02, .03, .04, .05, .06, .07, .08, .09, .1)) +
							scale_x_continuous(limits = c(0, 140), breaks = c(1, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140)) +
							theme_classic()
dens__label_length
ggsave(str_glue("{path}pics/labels_length__density.png"), dens__label_length, scale = 1.25, width = 7, height = 5, units = "in", dpi = 300)

## Describe tags
# Describe
matches__described <- matches |> rowwise() |>
						mutate(descriptor_str = describe_phrase(labels)) |>
						mutate(n_descr = str_count(descriptor_str, "\t") + 1) |>
						ungroup() |>
						mutate(string_description = str_replace_all(descriptor_str, "\t", ", ")) |>
						separate_longer_delim(cols = descriptor_str, delim = "\t") |>
						pivot_wider(names_from = descriptor_str, values_from = descriptor_str) |>
						mutate(across(!labels & !exact_from_title & !max_length_prop &
								!n_char & !category & !string_description, ~if_else(is.na(.), 0, 1)))
descriptors            <- names(matches__described |> select(-labels, -exact_from_title, -max_length_prop, -n_char, -category, -n_descr, -string_description)) |> as_tibble()
part_median_propLength <- matches__described |> filter(category == "partial_match") |> pull(max_length_prop) |> median()
part_median_nchar	   <- matches__described |> filter(category == "partial_match") |> pull(n_char) |> median()
exact_median_nchar	   <- matches__described |> filter(category == "exact_match")   |> pull(n_char) |> median()
n_all_descr			   <- matches__described |> pull(string_description) |> str_split(", ") |> unlist() |> unique() |> length()
matches__described     <- matches__described |> mutate(upper_prop = if_else(part_median_propLength > 2, 1, 0),
											upper_nchar = if_else( (n_char > part_median_nchar & category == "partial_match") | (n_char > exact_median_nchar & category == "exact_match"), 1, 0 ))
names <- c("labels", "exact_from_title", "max_length_prop", "n_char", "category", "n_descr",
						  "string_descr", rep("descriptor", n_all_descr), "upper_prop", "upper_nchar")
names(matches__described) <- names
matches__described        <- matches__described |> repair_names(prefix = "descriptor", sep = "_") |>
							       select("labels", "exact_from_title", "category", "max_length_prop", "n_char", "string_descr",
							 	           "upper_prop", "upper_nchar", starts_with("descriptor"))
# Group by descriptors
matches__grouped <- matches__described |>
						group_by_at(vars(category, upper_prop, upper_nchar, starts_with("descriptor"))) |>
						mutate(labels = labels |> str_c(collapse = " | "),
							   exact_from_title = exact_from_title |> str_c(collapse = " | "),
							   string_descr = string_descr |> str_c(collapse = " | ")) |>
						slice_head(n=1) |>
						ungroup() |>
						mutate(id = row_number())
# Select descriptors (temporary measure, has downsides)
n_select_descr    <- 19
exact_select      <- MRMR(matches__grouped |> filter(category == "exact_match") |>
					       select(starts_with("descriptor")) |> mutate_all(as.integer),
						  matches__grouped |> filter(category == "exact_match") |> pull(labels) |> as.factor(),
						  n_select_descr)
partial_select    <- MRMR(matches__grouped |> filter(category == "partial_match") |>
					       select(starts_with("descriptor")) |> mutate_all(as.integer),
						  matches__grouped |> filter(category == "partial_match") |> pull(labels) |> as.factor(),
						  n_select_descr)
# Select corresponding data
exact_select_names    <- names(exact_select$selection)
partial_select_names  <- names(partial_select$selection)
exact_selection       <- matches__grouped |> filter(category == "exact_match") |> select(id, upper_prop, upper_nchar, any_of(exact_select_names)) |>
							group_by(across(all_of(c("upper_prop", "upper_nchar", exact_select_names)))) |>
							mutate(ids = c(id |> unique() |> str_c(collapse = ", "))) |>
							slice_head(n = 1) |>
							ungroup() |>
							mutate(type = "exact") |>
							unite("binkey", upper_prop, upper_nchar, any_of(exact_select_names), sep = "", remove = FALSE) |>
							select(ids, binkey, type, upper_prop, upper_nchar, any_of(exact_select_names))
partial_selection       <- matches__grouped |> filter(category == "partial_match") |> select(id, upper_prop, upper_nchar, any_of(partial_select_names)) |>
							group_by(across(all_of(c("upper_prop", "upper_nchar", partial_select_names)))) |>
							mutate(ids = c(id |> unique() |> str_c(collapse = ", "))) |>
							slice_head(n = 1) |>
							ungroup() |>
							mutate(type = "partial") |>
							unite("binkey", upper_prop, upper_nchar, any_of(partial_select_names), sep = "", remove = FALSE) |>
							select(ids, binkey, type, upper_prop, upper_nchar, any_of(partial_select_names)) 
# Extend the dataset, as in https://keldysh.ru/ngpm/2025/43.pdf
featureSpace  <- thetaComb(theta = c(0,1), nfact = n_select_descr + 2, intercept = FALSE) |> as_tibble(.name_repair = "universal")
names(featureSpace) <- c("upper_prop", "upper_nchar", exact_select_names)
exact_featureSample <- featureSpace |> mutate(ids = "sample", type = "sample") |>
								 unite("binkey", upper_prop, upper_nchar, any_of(exact_select_names), sep = "", remove = FALSE) |>
								 select(ids, binkey, upper_prop, upper_nchar, any_of(exact_select_names)) |>
								 anti_join(exact_selection, by = "binkey") |>
								 slice_sample(prop = .0015)
names(featureSpace) <- c("upper_prop", "upper_nchar", partial_select_names)
partial_featureSample <- featureSpace |> mutate(ids = "sample", type = "sample") |>
								 unite("binkey", upper_prop, upper_nchar, any_of(partial_select_names), sep = "", remove = FALSE) |>
								 select(ids, binkey, type, upper_prop, upper_nchar, any_of(partial_select_names)) |>
								 anti_join(partial_selection, by = "binkey") |>
								 slice_sample(prop = .0015)
exact_4umap   <- bind_rows(exact_selection, exact_featureSample)
partial_4umap <- bind_rows(partial_selection, partial_featureSample)

## UMAP
set.seed(87)
exact_umap   <- umap(exact_4umap   |> select(-ids, -binkey, -type) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = n_select_descr + 1, n_components = 1)
partial_umap <- umap(partial_4umap |> select(-ids, -binkey, -type) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = n_select_descr + 1, n_components = 1)
exact_coords   <- exact_umap$layout |> bind_cols(exact_4umap |> select(ids)) |>
					rename(n = `...1`) |>
 					separate_longer_delim(ids, delim = ", ") |>
 					filter(ids != "sample") |>
 					mutate(ids = as.integer(ids)) |>
 					inner_join(matches__grouped, by = c("ids" = "id")) |>
 					select(n, ids, labels, exact_from_title, category) |>
 					arrange(n)
partial_coords <- partial_umap$layout |> bind_cols(partial_4umap |> select(ids)) |>
					rename(n = `...1`) |>
 					separate_longer_delim(ids, delim = ", ") |>
 					filter(ids != "sample") |>
 					mutate(ids = as.integer(ids)) |>
 					inner_join(matches__grouped, by = c("ids" = "id")) |>
 					select(n, ids, labels, exact_from_title, category) |>
 					arrange(n)

## Export the results
write_tsv(exact_coords, out_exact)
write_tsv(partial_coords, out_partial)