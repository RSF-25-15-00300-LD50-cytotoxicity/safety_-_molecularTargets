library(tidyverse)
library(patchwork)
library(umap)
library(praznik)
library(mirt)
library(foreach)
library(doParallel)

## Input
path             <- ".../"
words_short		 <- read_tsv(str_glue("{path}data/words_described.tsv")) |> filter(n_char > 2) |>
										filter(is_short == 1) |>
										mutate(w_id = row_number()) |>
										rename(str_descr = descriptor_string)

## Analyze short words
# Split for some efficiency
wd_short_list <- words_short |> mutate(split = row_number() %% 10) |>
					    		group_by(split) |>
					   	 		group_split()
rm(words_short)
gc()

## Prepare to process in parallel
cluster <- makeCluster(10)
registerDoParallel(cluster)

start <- Sys.time()
result <- foreach(data = wd_short_list, .combine = rbind, .packages = c("dplyr", "tidyr")) %dopar% {
						data |>
						unite("binkey", 10:18489, sep = "", remove = FALSE)
}
end   <- Sys.time()
end-start
## Stop cluster
stopCluster(cluster)
wd_short <- bind_rows(result)
wd_short <- wd_short |> group_by(binkey) |>
				mutate(w_ids = str_c(w_id, collapse = ", ")) |>
				slice_head(n=1) |>
				ungroup()
write_tsv(wd_short, str_glue("{path}data/short__words_d_united.tsv"))
## Binarize exact length
wd_short <- wd_short |> mutate(is_3 = if_else(n_char == 3, 1, 0),
				   is_4 = if_else(n_char == 4, 1, 0),
				   is_5 = if_else(n_char == 5, 1, 0),
				   is_6 = if_else(n_char == 6, 1, 0),
				   is_7 = if_else(n_char == 7, 1, 0))
# Select subset of descriptors, which disciminates between the words inside each length group
# Descriptors of lengthes are still here intentionally
n_d_short        <- 16
start <- Sys.time()
set.seed(86)
data_select      <- MRMR( wd_short |> select(-word, -w_id, -w_ids, -split, -binkey, -is_short,
										     -str_descr, -n_char, -n_descr,
											 -is_shorter, -is_long,
											 -is_longer, -is_neither,
											 -is_7, -is_6, -is_5, -is_4, -is_3) |> mutate_all(as.integer),
						  wd_short |> pull(w_ids) |> as.factor(),
						  n_d_short, threads = 10 )
end   <- Sys.time()
end-start
data_select_names  <- names(data_select$selection)
data_select_names
# SEE: https://stackoverflow.com/questions/47912107/dplyr-group-by-colnames-described-as-vector-of-strings
data <- wd_short |> select(word, w_ids, w_id, n_char, n_descr, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names)) |>
							mutate(w_ids = w_ids |> str_split(", "))    |>
							group_by(across(all_of(c("is_7", "is_6", "is_5", "is_4", "is_3", data_select_names)))) |>
							mutate(w_ids = c(w_ids |> unlist()) |> unique() |> str_c(collapse = ", ")) |>
							slice_head(n = 1) |>
							ungroup() |>
							mutate(type = "actual") |>
							unite("binkey", is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE)
# Extend the dataset, as in https://keldysh.ru/ngpm/2025/43.pdf
featureSpace  <- thetaComb(theta = c(0,1), nfact = n_d_short + 5, intercept = FALSE) |> as_tibble(.name_repair = "universal")
names(featureSpace) <- c("is_7", "is_6", "is_5", "is_4", "is_3", data_select_names)
featureSample <- featureSpace |> mutate(word = "sample", w_ids = "sample", w_id = 99999 + row_number(), n_char = 6, n_descr = 0) |>
							select(word, w_ids, w_id, n_char, n_descr, word, w_ids, w_id, n_char, n_descr, is_7, is_6, is_5, is_4, is_3, any_of(data_select_names)) |>
							unite("binkey", is_7, is_6, is_5, is_4, is_3, any_of(data_select_names), sep = "", remove = FALSE) |>
							anti_join(data, by = "binkey") |>
							slice_sample(prop = .0015)
data_space  <- bind_rows(data, featureSample)
data_2_umap <- data_space |> select("is_7", "is_6", "is_5", "is_4", "is_3", starts_with("descriptor")) |>
							mutate_all(as.integer)

set.seed(87)
data_umap <- umap( data_2_umap |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = n_d_short, n_components = 1 )
umap_coordinates <- data_umap$layout |> bind_cols(data_space |> select(w_ids)) |>
 										rename(n = `...1`) |>
 										separate_longer_delim(w_ids, delim = ", ") |>
 										inner_join(wd_short, by = "w_ids") |>
 										select(n, w_id, word, str_descr)

## Output:
write_tsv(umap_coordinates, str_glue("{path}data/ws_umap.tsv"))

# whether contains only number, special chars, etc. -> probably will be useful descriptor