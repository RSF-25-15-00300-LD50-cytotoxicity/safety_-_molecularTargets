library(tidyverse)
library(patchwork)

## Input
path       <- ".../"
input      <- str_glue("{path}articles/articles_gathered_titles.tsv")
output     <- str_glue("{path}pics/")
# Read and clear from unicode
articles   <- read.delim(input, header = FALSE, fileEncoding = "UTF-16LE", sep = "\t") |>
												 mutate(V1 = str_replace_all(V1, "\"", "")) |>
												 mutate(V1 = str_replace_all(V1, " ", " ")) |>
												 mutate(V1 = str_replace_all(V1, " ", " ")) |>
												 mutate(V1 = gsub("[^\x01-\x7F]", "", V1))

## Process
# Calculate the the lengthes
articles_processed <- articles |> mutate(n_words = str_count(V1, "\\b") / 2,																				 n_chars = str_length(V1))
# Summarize the lengthes
n_words_sum <- articles_processed |> select(n_words) |> group_by(n_words) |> summarize(n = n()) |> arrange(n_words)
n_chars_sum <- articles_processed |> select(n_chars) |> group_by(n_chars) |> summarize(n = n()) |> arrange(n_chars)

## Plot the results
w_plot <- ggplot(n_words_sum |> mutate(n_words = fct_reorder(as.character(n_words), n_words))) +
			geom_bar( stat="identity", aes(x=n_words, y=n), color="#334996", linewidth = .15, fill="grey85") +
			scale_y_continuous(limits = c(0, 2100), breaks = c(100, 250, 500, 1500, 2000)) +
			labs(x="number of words", y="corresponding number of titles") +
			theme_classic() +
			theme(axis.text.x = element_text(size = 5, vjust = 0.5))
c_plot <- ggplot(n_chars_sum |> mutate(n_words = fct_reorder(as.character(n_chars), n_chars))) +
			geom_bar( stat="identity", aes(x=n_chars, y=n), color="#334996", linewidth = .15, fill="grey85") +
			scale_y_continuous(limits = c(0, 300), breaks = c(50, 100, 150, 200, 250, 300)) +
			labs(x="number of characters") +
			theme_classic() +
			theme(axis.title.y = element_blank(), axis.text.x = element_text(vjust = 0.5))
plot <- w_plot + c_plot
plot

## Save the plot
ggsave(str_glue("{output}1__length_distr.png"), plot, scale = 1.25, width = 7, height = 3, units = "in", dpi = 300)
