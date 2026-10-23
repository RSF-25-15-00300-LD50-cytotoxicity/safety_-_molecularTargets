library(tidyverse)
library(patchwork)

## Function to describe words
describe_w <- function(w) {
	w_vec  <- str_split(w, "") |> unlist()
	d_vec <- rep(NA, length(w_vec))
	for (i in seq(1:length(w_vec))) {
		lft  <- w_vec[i-1]
		cntr <- w_vec[i]
		rght <- w_vec[i+1]
		if (is_empty(lft)) {lft = ""}
		if (is.na(rght)) {rght = ""}
		d_vec[i] <- str_c(lft,cntr,rght, collapse = "")
	}
	d_str <- d_vec |> unique() |> sort() |> str_c(collapse = "\t")
	d_str
}

## Input
path     <- ".../"
articles <- read_tsv(str_glue("{path}articles/articles_gathered.tsv")) |> mutate(title = str_replace_all(title, '""', "'")) |>
										mutate(title = str_replace_all(title, '"', "'"))

## Prepare
intermediate <- articles |> select(title) |> mutate(n_word = str_count(title, " ") + 1)
longest      <- intermediate |> pull(n_word) |> max()
words    	 <- tibble(word = intermediate |> select(title) |>
							   mutate(title = str_to_lower(title)) |>
							   separate_wider_delim(cols = title, delim = " ", names = rep("x", longest),
													names_repair = "unique", too_few = "align_start") |>
							   		mutate_all(str_trim) |>
							   		unlist()  |>
							   		unique()) |>
						filter(!is.na(word))

## Describe words
words_described_raw <- words |> mutate(nchar = str_length(word)) |>
							filter(nchar > 2) |>
							rowwise() |>
							mutate(descriptor_str = describe_w(word)) |>
							ungroup()
# Assess the distribution of lengthes
hist_length <- ggplot(words_described_raw, aes(nchar)) +
				geom_histogram(bins = 30, color = "black", fill = "grey90") +
				ggtitle("a") +
				scale_y_continuous(limits = c(0, 6500), breaks = c (500, 1000, 2000, 3000, 4000, 5000, 6000, 6500)) +
				scale_x_sqrt(breaks = c(1, 10, 20, 30, 60, 90, 120)) +
				theme_classic() +
				theme(plot.title = element_text(hjust = 1))
hist_length
words_described_raw_lim <- words_described_raw |> filter(nchar < 31)
wdl_quant <- quantile(words_described_raw_lim |> pull(nchar), probs = c(.25, .5, 0.75), names = TRUE, type = 7)
hist_length_lim <- ggplot(words_described_raw_lim, aes(nchar)) +
				geom_histogram(bins = 30, color = "black", fill = "grey90") +
				geom_vline(xintercept = wdl_quant[1], color = "#800000ff", linetype = "dashed", linewidth = 1.25) +
				geom_vline(xintercept = wdl_quant[2], color = "#800000ff", linetype = "dashed", linewidth = 1.25) +
				geom_vline(xintercept = wdl_quant[3], color = "#800000ff", linetype = "dashed", linewidth = 1.25) +
				ggtitle("b") +
				scale_y_continuous(limits = c(0, 6500), breaks = c (500, 1000, 2000, 3000, 4000, 5000, 6000, 6500)) +
				scale_x_continuous(limits = c(0, 31), breaks = c(1, 10, 20, 30)) +
				theme_classic() +
				theme(plot.title = element_text(hjust = 1))
hist_length_lim
hist_plot <- hist_length + hist_length_lim
hist_plot
ggsave(str_glue("{path}pics/word_length__distr.png"), hist_plot, scale = 1.25, width = 7, height = 4, units = "in", dpi = 300)
# Binarize the description of lengthes
wd_processing <- words_described_raw |> mutate(is_long     = if_else(nchar > 30, 1, 0),
											   is_short    = if_else(nchar < 8, 1, 0),
											   is_longer   = if_else(nchar > 13 & nchar < 31, 1, 0),
											   is_shorter  = if_else(nchar > 7 & nchar < 11, 1, 0),
											   is_neither  = if_else(nchar > 10 & nchar < 14, 1, 0))
# Binarize the fragment descriptors
wd_processing <- wd_processing |> mutate(ndescr = str_count(descriptor_str, "\t") + 1)
max_descr     <- wd_processing |> pull(ndescr) |> max()
wd_binarized  <- wd_processing |> select(word, descriptor_str, nchar, ndescr, is_short, is_shorter, is_neither, is_longer, is_long) |>
								  mutate(string_description = descriptor_str) |>
								  mutate(descriptor_str     = str_replace_all(descriptor_str, "\t", ", ")) |>
						          separate_longer_delim(cols = string_description, delim = "\t") |>
								  pivot_wider(names_from = string_description, values_from = string_description) |>
								  mutate(across(!word & !nchar & !ndescr & !is_short & !is_shorter
								  	& !is_neither & !is_longer & !is_long & !descriptor_str, ~if_else(is.na(.), 0, 1)))
wd_names <- wd_names <- c("word", "descriptor_string", "n_char", "n_descr", "is_short", "is_shorter", "is_neither", "is_longer", "is_long", rep("descriptor", 37421))
names(wd_binarized) <- wd_names
wd_binarized <- wd_binarized |> repair_names(prefix = "descriptor", sep = "_")
# Save the current results
write_tsv(wd_binarized, str_glue("{path}data/words_described.tsv"))