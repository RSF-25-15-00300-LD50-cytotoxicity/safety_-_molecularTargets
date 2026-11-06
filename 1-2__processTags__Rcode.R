library(tidyverse)

## Input
path      	  <- "C:/Users/XPS/Documents/RSCF/25-15-00300_preclinTox_DAF/2026/activity_lists/"
input     	  <- str_glue("{path}data/articles_titles_ontologies__v2.tsv")
output        <- str_glue("{path}data/articles_titles_ontologie_ok.tsv")
# The following line:
# str_replace_all("\"{4}", "") |>
# was a big mistake (2 days or so), applied in the following pipeline just to make text prettier
# it shifted of matches' positions
# the point is: such  a thing should de done prior to or after the whole analysis only
articles_raw  <- read_file(input) |> as_tibble()  |>
							separate_longer_delim(value, delim = "\n") |>
							filter(value != "") |>
							filter(value != "text\tpos\tlabels\tontologies") |>
							separate_wider_delim(value, delim = "\t", names = c("text", "pos", "labels", "ontologies")) |>
							mutate(id = row_number())				

# The first big task is to explode the records by distinct titles
pos_proc <- articles_raw |> rowwise() |>
							# delete IDs of the titles
							# find the pos where title ends
							mutate(sep_pos = (str_locate_all(text, ' \\| '))[[1]][,1] |> str_c(collapse = ",")) |>
							# make things more tidy
							separate_longer_delim(c(pos, labels, ontologies), delim = " | ") |>
							select(id, sep_pos, pos, labels, ontologies, text) |>
							# find the exact title in group for each match
							separate_wider_delim(pos, delim = " - ", names = c("pos_s", "pos_e")) |>
							mutate(pos_s = as.integer(pos_s), pos_e = as.integer(pos_e)) |>
							rowwise() |>
							mutate(title_n = which(sep_pos |> str_split(",") |> unlist() |> as.integer() >= pos_e)[1]) |>
							mutate(exact_from_txt = str_sub(text, pos_s+1, pos_e)) |>
							mutate(title = (text |> str_split(" \\|") |> unlist())[title_n] |> str_trim()) |>
							ungroup() |>
							filter(title_n < 101) |>
							rename(exact_from_title = exact_from_txt)

# Prepare the results to be saved
onto_sum			  <- pos_proc |> select(labels, ontologies) |> group_by(ontologies) |> summarise(n = n())
unique_matches <- pos_proc |> select(labels, exact_from_title) |>
									 distinct() |>
									 rowwise()   |>
									 mutate(max_length_prop = max((str_length(labels) / str_length(exact_from_title)), (str_length(exact_from_title) / str_length(labels))) |> round(0)) |>
									 ungroup()
result				  <- pos_proc |> select(id, pos_s, pos_e, labels, exact_from_title, ontologies, text) |> distinct()
um_sum				  <- unique_matches |> group_by(max_length_prop) |> summarise(n = n()) |>
												  mutate(max_length_prop = as_factor(max_length_prop))
prop_plot			  <- ggplot(um_sum |> mutate(max_length_prop = fct_reorder(max_length_prop, n))) +
									geom_segment( aes(x=max_length_prop, xend=max_length_prop, y=0, yend=n), color="black") +
									geom_point(   aes(x=max_length_prop, y=n), shape=21, size=6, fill = "grey85", color = "#800000ff" ) +
									theme_classic() +
									scale_y_sqrt()  +
									theme(axis.title.x = element_blank(), axis.title.y = element_blank(), axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
prop_plot
onto_plot			  <- ggplot(onto_sum |> mutate(ontologies = fct_reorder(ontologies, n))) +
									geom_segment( aes(x=ontologies, xend=ontologies, y=0, yend=n), color="black") +
									geom_point(   aes(x=ontologies, y=n), shape=21, size=6, fill = "grey85", color = "#800000ff" ) +
									theme_classic() +
									scale_y_sqrt()  +
									theme(axis.title.x = element_blank(), axis.title.y = element_blank(), axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))
onto_plot

# Save the results
ggsave(str_glue("{path}pics/ontologies_in_all.png"), onto_plot, scale = 1.25, width = 7, height = 3, units = "in", dpi = 300)
ggsave(str_glue("{path}pics/lengthes_props.png"),    prop_plot, scale = 1.25, width = 7, height = 3, units = "in", dpi = 300)

#write_tsv(result, 		  str_glue("{path}data/titles_vs_ontologies.tsv")) # this is quite large, may be conviniet to check the results, but pretty much useless when * is OK
write_tsv(result |> select(-text), str_glue("{path}data/only-titles_vs_ontologies.tsv"))
write_tsv(unique_matches, str_glue("{path}data/matches_unique.tsv"))
write_tsv(um_sum, 		  str_glue("{path}data/unique_matches_summ.tsv"))
write_tsv(onto_sum, 	  str_glue("{path}data/ontologies_summ.tsv"))