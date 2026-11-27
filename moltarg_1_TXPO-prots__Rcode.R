library(tidyverse)
#https://bioportal.bioontology.org/ontologies/ODAE, CSV

## Input
txpo_raw <- read_csv(".../molecular_targets__fromOntologies/TXPO.csv",
					 guess_max = 10000)
names <- names(txpo_raw)
ontologies_inClasses <- txpo_raw |> pull(`Class ID`) |> str_replace("http://purl.obolibrary.org/obo/", "") |> str_replace("_.*", "") |> unique() |> sort()
#names
# class: IMR, OGG,
# class: GO - processes, also, should be useful latter
prots_txpo <- txpo_raw |> filter(str_detect(`Class ID`, "IMR")) |>
					select(name = `Preferred Label`, syn = Synonyms) |> distinct()

# Export
write_tsv(prots_txpo, ".../molecular_targets__fromOntologies/TXPO_gene&prot.csv")