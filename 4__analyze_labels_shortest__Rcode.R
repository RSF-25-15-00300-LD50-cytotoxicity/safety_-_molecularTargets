library(tidyverse)

## Input
path             <- ".../"
input			 <- str_glue("{path}data/shortest__words_d_united__labeled.tsv")
w_label   		 <- read.delim(input, fileEncoding = "UTF-16LE", sep = "\t") |>
								  select(-umap, -w_ids, -str_descrs) |>
								  as_tibble() |>
								  group_by(words) |>
								  mutate_at(vars(-group_cols()), ~replace_na(., 0)) |>
								  mutate_at(vars(-group_cols()), ~sum(.)) |>
								  mutate_at(vars(-group_cols()), ~if_else(. > 1, 1, .)) |>
								  slice_head(n = 1) |>
								  ungroup()

## Summarize
wl_summ 		 <- w_label |> summarise(across(entity_biased:cause_biased, sum)) |>
							   pivot_longer(cols = 1:7, names_to = "category", values_to = "n")
# Plot
label_plot		 <- ggplot(wl_summ |> mutate(category = fct_reorder(category, n))) +
					geom_segment( aes(x=category, xend=category, y=0, yend=n), color="black") +
					geom_point(   aes(x=category, y=n), shape=21, size=6, fill = "grey85", color = "#800000ff" ) +
					theme_classic() +
					theme(axis.title.x = element_blank(), axis.title.y = element_blank(), axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
label_plot

## Output
ggsave(str_glue("{path}pics/shortest__categories.png"), label_plot, scale = 1.25, width = 7, height = 4, units = "in", dpi = 300)