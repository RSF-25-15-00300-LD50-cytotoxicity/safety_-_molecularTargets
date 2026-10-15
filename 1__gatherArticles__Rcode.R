library(tidyverse)
## Input
path <- "..."
# List files from AAL
raw_fn <- list.files(path, full.names = TRUE, pattern = "*.csv")

# Read the files and combine them into the single tiible, assuming variable and unknown numbers of rows
articles <- tibble(pmid = NA,title = NA,auth = NA,citation = NA,first_auth = NA,
				   source = NA,pubyear = NA,created=NA,pmcid=NA,nihms_id=NA,doi=NA)
for (i in seq(1:length(raw_fn))) {
	path_line <- str_glue("{raw_fn[i]}")
	articles_j <- read_csv(path_line, col_names = FALSE)
	colnames(articles_j) <- c("pmid","title","auth","citation","first_auth",
				   				"source","pubyear","created","pmcid","nihms_id","doi")
	articles <- rbind(articles, articles_j)
}
articles <- articles |> filter(!is.na(pmid) & title != "Title")

## Output
write_tsv(articles, str_glue("{path}articles_gathered.tsv"))