library(tidyverse)
library(patchwork)
library(umap)
library(praznik)
library(mirt)
library(foreach)
library(doParallel)

## Input
path             <- ".../"
words_shortest   <- read_tsv(str_glue("{path}data/words_described.tsv")) |>
										filter(is_shortest == 1) |>
										mutate(w_id = row_number()) |>
										rename(str_descr = descriptor_string) |>
										mutate(is_3 = if_else(n_char == 3, 1, 0),
				   							   is_4 = if_else(n_char == 4, 1, 0),
				                               is_5 = if_else(n_char == 5, 1, 0),
				                               is_6 = if_else(n_char == 6, 1, 0),
				                               is_7 = if_else(n_char == 7, 1, 0)) |>
								select(word_raw, word, w_id, str_descr, n_char, n_descr,
											 is_ascii, is_7, is_6, is_5, is_4, is_3, starts_with("descriptor"))

## Analyze short words
# Split for some efficiency
wd_shortest_list <- words_shortest |> mutate(split = row_number() %% 10) |>
					    		group_by(split) |>
					   	 		group_split()
initial_cols <- ncol(words_shortest)
rm(words_shortest)
gc()

## Prepare to process in parallel
cluster <- makeCluster(10)
registerDoParallel(cluster)

start <- Sys.time()
result <- foreach(data = wd_shortest_list, .combine = rbind, .packages = c("dplyr", "tidyr")) %dopar% {
						data |>
						unite("binkey_raw", 7:initial_cols, sep = "", remove = FALSE)
}
end   <- Sys.time()
end-start
## Stop cluster
stopCluster(cluster)
wd_shortest <- bind_rows(result)
wd_shortest <- wd_shortest |> group_by(binkey_raw) |>
					mutate(w_ids = str_c(w_id, collapse = ", ")) |>
					mutate(words_raw  = str_c(word_raw  |> unique() |> sort(), collapse = " ### ")) |>
					mutate(words      = str_c(word      |> unique() |> sort(), collapse = " ### ")) |>
					mutate(str_descrs = str_c(str_descr |> unique() |> sort(), collapse = " ### ")) |>
					slice_head(n=1) |>
					ungroup() |>
					select(words_raw, words, w_ids, str_descrs,
							is_ascii, is_7, is_6, is_5, is_4, is_3, starts_with("descriptor"))
write_tsv(wd_shortest, str_glue("{path}data/shortest__words_d_united.tsv"))
# Select subset of descriptors, which disciminates between the words inside each length group
# Descriptors of lengthes are still here intentionally
n_d_shortest     <- 15
start <- Sys.time()
set.seed(86)
data_select      <- MRMR( wd_shortest |> select(-words_raw, -words, -w_ids, -str_descrs,
												-is_ascii, -is_7, -is_6, -is_5, -is_4, -is_3) |> mutate_all(as.integer),
						  wd_shortest |> pull(w_ids) |> as.factor(),
						  n_d_shortest, threads = 10 )
end   <- Sys.time()
end-start
data_select_names  <- names(data_select$selection)
data_select_names
# SEE: https://stackoverflow.com/questions/47912107/dplyr-group-by-colnames-described-as-vector-of-strings
data <- wd_shortest |> mutate(w_ids = w_ids |> str_split(", ")) |>
							group_by(across(all_of(c("is_ascii", "is_7", "is_6", "is_5", "is_4", "is_3", data_select_names)))) |>
							mutate(w_ids = c(w_ids |> unlist()) |> unique() |> str_c(collapse = ", ")) |>
							slice_head(n = 1) |>
							ungroup() |>
							mutate(type = "actual") |>
							unite("binkey", is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE) |>
							select(w_ids, binkey, is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names))
# Extend the dataset, as in https://keldysh.ru/ngpm/2025/43.pdf
featureSpace  <- thetaComb(theta = c(0,1), nfact = n_d_shortest + 6, intercept = FALSE) |> as_tibble(.name_repair = "universal")
names(featureSpace) <- c("is_ascii", "is_7", "is_6", "is_5", "is_4", "is_3", data_select_names)
featureSample <- featureSpace |> mutate(word_raw = "sample", word = "sample", w_ids = "sample", w_id = 99999 + row_number(), n_char = 6, n_descr = 0) |>
								 unite("binkey", is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE) |>
								 select(w_ids, binkey, is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names)) |>
								 anti_join(data, by = "binkey") |>
								 slice_sample(prop = .0015)
# Speciffically include UP and DOWN
top   <- featureSample[1,] |> mutate(word_raw = "top", word = "top", w_ids = "top", w_id = 999999, n_char = 7, n_descr = 0,
									is_ascii = 1, is_7 = 1, is_6 = 1, is_5 = 1, is_4 = 1 , is_3 = 1) |>
						     mutate_at(vars(starts_with("descriptor")), ~1) |>
						     select(-binkey) |>
							 unite("binkey", is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE) |>
						     select(w_ids, binkey, is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names))
bottom <- featureSample[1,] |> mutate(word_raw = "bottom", word = "bottom", w_ids = "bottom", w_id = -1, n_char = 0, n_descr = 0,
									is_ascii = 0, is_7 = 0, is_6 = 0, is_5 = 0, is_4 = 0 , is_3 = 0) |>
						     mutate_at(vars(starts_with("descriptor")), ~1) |>
						     select(-binkey) |>
							 unite("binkey", is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE) |>
						     select(w_ids, binkey, is_ascii, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names))
featureSample <- bind_rows(featureSample |> anti_join(top, by = "binkey"), top)
featureSample <- bind_rows(featureSample |> anti_join(bottom, by = "binkey"), bottom)
data_space  <- bind_rows(data, featureSample)
data_2_umap <- data_space |> select("is_ascii", "is_7", "is_6", "is_5", "is_4", "is_3", starts_with("descriptor")) |>
							mutate_all(as.integer)
gc()
set.seed(87)
data_umap <- umap( data_2_umap |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = n_d_shortest + 5, n_components = 1 )
umap_coordinates <- data_umap$layout |> bind_cols(data_space |> select(w_ids)) |>
 										rename(n = `...1`) |>
 										separate_longer_delim(w_ids, delim = ", ") |>
 										inner_join(wd_shortest |> separate_longer_delim(w_ids, delim = ", "), by = "w_ids") |>
 										select(n, w_ids, str_descrs, words, words_raw)

## Output:
write_tsv(umap_coordinates, str_glue("{path}data/ws_umap.tsv"))