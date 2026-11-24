library(tidyverse)
library(SnowballC)
library(umap)
library(rgl)
library(plotly)
library(lacunr)
library(wakefield)

### Sort of experimental approach, technical aspects are not quite sturdy
### should be OK, since the manual screening is planned
## Some functions
describe_phrase__l <- function(phrase) {
	phrase <- str_to_lower(phrase)
	p_vec  <- str_split(phrase, "") |> unlist()
	d_vec <- rep(NA, length(p_vec))
	for (i in seq(1:length(p_vec))) {
		lft  <- p_vec[i-1]
		cntr <- p_vec[i]
		rght <- p_vec[i+1]
		if (is_empty(lft)) {lft = ""}
		if (is.na(rght)) {rght = ""}
		d_vec[i] <- str_c( "d__d__", str_c( lft, cntr, rght, collapse = ""), collapse = "")
	}
	d_str <- d_vec |> unique() |> sort() |> str_c(collapse = "\t")
	d_str
}
describe_phrase__w <- function(phrase) {
	phrase <- str_to_lower(phrase)
	p_vec  <- str_split(phrase, "[\\s-]") |> map(wordStem) |> unlist()
	d_vec <- rep(NA, length(p_vec))
	for (i in seq(1:length(p_vec))) {
		first  <- p_vec[i-1]
		second <- p_vec[i]
		if (is_empty(first)) {first = ""}
		if (is.na(second)) {second = ""}
		d_vec[i] <- str_c("d__d__", str_c( first, second, collapse = ""), collapse = "")
	}
	d_str <- d_vec |> unique() |> sort() |> str_c(collapse = "\t")
	d_str
}

## Input
path      <- ".../data/"
# Read titles
titles    <- read_tsv(str_glue("{path}titles_described.tsv"))

## Describe further
#  Get descriptors
titles_described <- titles |> rowwise() |>
						mutate(l_tripple = describe_phrase__l(title),
							   w_tripple = describe_phrase__w(title)) |>
						mutate(d__lw = c(str_split(l_tripple, "\t") |> unlist(), str_split(w_tripple, "\t") |> unlist()) |> unique() |> sort() |> str_c(collapse = "\t")) |>
						ungroup() |>
						select(-l_tripple, -w_tripple) |>
						pivot_wider(names_from = d__lw, values_from = d__lw) |>
						mutate_at(vars(starts_with("d__d__")), ~if_else(is.na(.), 0, 1)) |>
						mutate_at(vars(starts_with("d__d__")), as.integer)

## Reduce the dimensionality, two-stage procedure to emphasize the role of ontology mappings
# Reducing structural features of the titles
titles_s <- titles_described |> select(title, starts_with("d__d__")) |>
								group_by(across(starts_with("d__d__"))) |>
								mutate(title = str_c(title, collapse = " | ")) |>
								slice_head(n = 1) |>
								ungroup()
# Reduce
set.seed(87)
s_umap <- umap(titles_s |> select(-title) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = 20, n_components = 3)
title_s_xyz <- s_umap$layout |> bind_cols(titles_s |> select(title)) |>
					rename(X = `...1`, Y = `...2`, Z = `...3`,) |>
 					separate_longer_delim(title, delim = " | ")
# Export, just in case (computationally expensive)
write_tsv(title_s_xyz, str_glue("{path}title_s_xyz.tsv"))
# Read if needed
titles_s_xyz <- read_tsv(str_glue("{path}title_s_xyz.tsv")) |> rename(X=x, Y=y, Z=z) 
# Visualize
plot_ly(x = titles_s_xyz$x, y = titles_s_xyz$y, z = titles_s_xyz$z,
			type = "scatter3d", size = .5)
# Binarize the resulting UMAP coordinates via voxelization
titles_s_voxels <- voxelize( titles_s_xyz |> as.data.frame() |> select(-title),
							c(1.5, 1.5, 1.5), threads = 10 ) |>
					as_tibble() |> 
					# assign IDs to voxels
					mutate(id = str_c("d__u__", row_number())) |>
					mutate(xmin = X - .75, xmax = X + .75,
						   ymin = Y - .75, ymax = Y + .75,
						   zmin = Z - .75, zmax = Z + .75)
# Assign actual points to voxels
titles_s_xyz$voxel   = rep(NA, nrow(titles_s_xyz))
titles_s_xyz$voxel_n = rep(NA, nrow(titles_s_xyz))
for (i in seq(1:nrow(titles_s_xyz))) {
	for (k in seq(1:nrow(titles_s_voxels))) {
		if( titles_s_voxels[k,6]  |> pull() < titles_s_xyz[i,1] |> pull() &
		    titles_s_voxels[k,7]  |> pull() > titles_s_xyz[i,1] |> pull() &
		    titles_s_voxels[k,8]  |> pull() < titles_s_xyz[i,2] |> pull() &
		    titles_s_voxels[k,9]  |> pull() > titles_s_xyz[i,2] |> pull() &
		    titles_s_voxels[k,10] |> pull() < titles_s_xyz[i,3] |> pull() &
		    titles_s_voxels[k,11] |> pull() > titles_s_xyz[i,3] |> pull()  ) {
			titles_s_xyz[i,5] <- titles_s_voxels[k,5] |> pull()
			titles_s_xyz[i,6] <- titles_s_voxels[k,4] |> pull()
			break
		}
	}
}
# Binarize belonging to voxels
titles_s_bin <- titles_s_xyz |> select(-voxel_n) |> pivot_wider(names_from = voxel, values_from = voxel) |>
						mutate_at(vars(starts_with("d__u__")), ~if_else(is.na(.), 0, 1)) |>
						mutate_at(vars(starts_with("d__u__")), as.integer)

## Reduce again using manual labels, ontologies and binarized UMAP results
# Prepare the data
titles_lou <- titles_described |> select(-starts_with("d__d__")) |>
						  inner_join(titles_s_bin, by = "title") |>
						  select(-X, -Y, -Z) |>
						  rowwise() |>
						  mutate(binkey = across(2:61, ~str_c(., collapse = ""))) |>
						  ungroup() |>
						  group_by(binkey) |>
						  unite("binkey", 2:61, remove = FALSE) |>
						  slice_head(n=1) |>
						  ungroup() |>
						  mutate(category = "actual") |>
						  select(title, binkey, category, starts_with("d__")) |>
						  mutate_at(vars(starts_with("d__")), as.integer)
#Prepare the additional points, probably not needed this time. Just in case for future studies
set.seed(92)
space <- tibble(title = rep("sample", 60000), category = rep("sample", 60000), binkey = rep(NA, 60000)) |>
			rowwise() |>
			mutate(binkey = r_sample_integer(60, x = 0:1) |> str_c(collapse = "_")) |>
			ungroup() |>
			group_by(binkey) |>
			slice_head(n = 1) |>
			ungroup() |>
			mutate(sepkey = binkey) |>
			separate_wider_delim(cols = sepkey, delim = "_", names_sep = "_") |>
			anti_join(titles_lou, by = "binkey") |>
			slice_sample(n = 30000) |>
			mutate_at(vars(starts_with("sepkey")), as.integer)
names(space) <- names(titles_lou)
data_2_umap <- bind_rows(titles_lou, space) |> filter(!is.na(d__safety))

## UMAP
set.seed(57)
lou_umap    <- umap(data_2_umap |> filter(title != "sample") |> select(-title, -binkey, -category) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = 15, n_components = 1)
lou_umap_xy <- umap(data_2_umap |> filter(title != "sample") |> select(-title, -binkey, -category) |> as.data.frame(), preserve.seed = TRUE, metric = "manhattan", n_neighbors = 15, n_components = 2)
title_lou_n <- lou_umap$layout |> bind_cols(data_2_umap |> filter(title != "sample") |> select(title, category, d__safety)) |>
					rename(n = `...1`) |>
					arrange(n) |>
 					separate_longer_delim(title, delim = " | ")
title_lou_xy <- lou_umap_xy$layout |> bind_cols(data_2_umap |> filter(title != "sample") |> select(title, d__safety)) |>
					rename(x = `...1`, y = `...2`) |>
 					separate_longer_delim(title, delim = " | ")

## Export the results
write_tsv(title_lou_n,  str_glue("{path}titles_lou_n.tsv"))
write_tsv(title_lou_xy, str_glue("{path}titles_lou_xy.tsv"))