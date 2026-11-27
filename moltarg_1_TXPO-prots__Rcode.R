library(tidyverse)
#https://bioportal.bioontology.org/ontologies/ODAE, CSV

## Input
txpo_raw <- read_csv(".../TXPO.csv",
					 guess_max = 10000)
names <- names(txpo_raw)
ids   <- names |> as_tibble() |> filter(str_detect(value, "ID")) |> pull(value)
#names
#ids
ontologies_inClasses <- txpo_raw |> pull(`Class ID`) |> str_replace("http://purl.obolibrary.org/obo/", "") |> str_replace("_.*", "") |> unique() |> sort()
# class: IMR - proteins, OGG - genes,
# class: GO  - biological processes
prots_txpo <- txpo_raw |> filter(str_detect(`Class ID`, "IMR")) |>
					select(name = `Preferred Label`, syn = Synonyms, ncbi_geneid = `NCBI GeneID`) |> distinct()
procs_txpo <- txpo_raw |> filter(str_detect(`Class ID`, "GO")) |>
					select(id = `Class ID`, name = `Preferred Label`) |> distinct()

# Export
write_tsv(prots_txpo, ".../TXPO_proteins.tsv")
write_tsv(procs_txpo, ".../TXPO_GO.tsv")