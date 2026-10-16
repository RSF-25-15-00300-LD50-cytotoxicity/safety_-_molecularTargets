library(tidyverse)
library(tm)
library(umap)

## Input
path <- "..."
# Main set
data <- read_tsv(str_glue("{path}articles_gathered.tsv")) |>
										  select(pmid, title) |>
										  rename(doc_id = pmid, text = title) |>
										  mutate(doc_id = as.character(doc_id))
##Processing
# Text to DTM, SEE: https://cran.r-project.org/web/packages/tm/vignettes/tm.pdf
source_text <- DataframeSource(data)
corpus_text <- VCorpus(source_text) |> tm_map(stripWhitespace) |>
							 tm_map(content_transformer(tolower)) |>
							 tm_map(removeWords, stopwords("english")) |>
							 tm_map(stemDocument)
dt_matrix_text <- DocumentTermMatrix(corpus_text)     |> weightBin()
# Process terms / tokens the same way:
# there are ~32k of them and I have a guess thath this number of descriptors is way too much
# to describe ~25k articles' titles (1 sentence each)
# Smth has to be done
terms_raw <- dt_matrix_text$dimnames$Terms |> as_tibble() |>
									 	mutate(doc_id = row_number(), text = value) |>
									 	rowwise() |>
									 	mutate(text = str_split(text, "") |> unlist() |> sort() |> unique() |> str_c(collapse = " ")) |>
									 	ungroup() |>
									 	select(doc_id, value, text) |>
									 	separate_longer_delim(text, delim = " ") |>
									 	distinct() |>
									 	pivot_wider(names_from = text, values_from = text) |>
									 	mutate(across(!doc_id & !value, ~if_else(is.na(.), 0, 1)))
terms <- terms_raw |> unite("key", 3:ncol(terms_raw), remove = FALSE) |>
					  group_by(key) |>
					  mutate(doc_id = doc_id |> sort() |> unique() |> str_c(collapse = "_")) |>
					  slice_head(n=1) |>
					  ungroup() |>
					  select(-key)

## UMAP the terms for convinience of the further processing, global structure is not so important this case
set.seed(87)
data_umap <- umap( terms |> select(-doc_id, -value) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = 25, n_components = 1 ) 
umap_coordinates <- data_umap$layout |> bind_cols(terms |> select(doc_id)) |>
										rename(pos = `...1`) |>
										separate_longer_delim(doc_id, delim = "_") |>
										inner_join(terms_raw |> mutate(doc_id = as.character(doc_id)), by = c("doc_id" = "doc_id")) |>
										select(doc_id, value, pos) |>
										arrange(pos)

## Output
write_tsv(umap_coordinates, str_glue("{path}terms_sorted.tsv"))