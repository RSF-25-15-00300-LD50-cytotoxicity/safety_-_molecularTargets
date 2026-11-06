library(tidyverse)
library(httr2)
library(stringi)

#red delete special chars like NBSP
## Input
path       <- ".../"
input      <- str_glue("{path}articles/articles_gathered_titles.tsv")
output     <- str_glue("{path}data/articles_titles_ontologies__v2.tsv")
articles   <- read.delim(input, header = FALSE, fileEncoding = "UTF-16LE", sep = "\t") |>
												 mutate(V1 = str_replace_all(V1, "\"", "")) |>
												 mutate(V1 = str_replace_all(V1, " ", " ")) |>
												 mutate(V1 = str_replace_all(V1, " ", " ")) |>
												 mutate(V1 = gsub("[^\x01-\x7F]", "", V1))


## Prepare the POST request to annotate the titles.
# Considering that external API will be quered, it is important to have some limits
# At the moment there are no such recomendations at https://www.ebi.ac.uk/ols4/api-docs
# So, we have ~25k strings; it seems reasonable to divide this array into chunks of 100 records and
# send them with the pause of 3 seconds between receiving the results and sending new query (~ 13 mins of pure waiting plus processing time)
# minor obstacle is that, as far as I can see, it is not allowed to send multiple (distinct) texts to be annotated:
# thus, titles should be glued together and only afterwards, we it will be possible to deduce from which particular title the particluar term is 

# httr2, https://cran.r-project.org/web/packages/httr2/refman/httr2.html,
# has the following instructions to construct the POST queries:
# request("https://httpbin.org/post") |>  target LINK with some parameters goes here
#  req_body_json(list(name = "value")) |> strings to be annotated go here
#  req_perform() |>                       execute request
#  resp_body_json()                       get JSON with the results

# The following dummy request works:
# dummy_result <- request("https://www.ebi.ac.uk/ols4/api/v2/tag_text?ontologyId=aeo&ontologyId=aio&ontologyId=aro&ontologyId=bao&ontologyId=bmont&ontologyId=bto&ontologyId=cco&ontologyId=cdao&ontologyId=chebi&ontologyId=cheminf&ontologyId=chiro&ontologyId=chmo&ontologyId=cio&ontologyId=cl&ontologyId=clo&ontologyId=cmpo&ontologyId=cbo&ontologyId=dron&ontologyId=disdriv&ontologyId=dideo&ontologyId=efo&ontologyId=exo&ontologyId=gexo&ontologyId=mesh&ontologyId=mamo&ontologyId=mod&ontologyId=mmo&ontologyId=mi&ontologyId=ncbitaxon&ontologyId=ms&ontologyId=mondo&ontologyId=obi&ontologyId=oae&ontologyId=ogms&ontologyId=phipo&ontologyId=symp&ontologyId=vario&ontologyId=txpo&ontologyId=wikipathways&ontologyId=vo&ontologyId=xco&ontologyId=xlmod&minLength=3&includeSubstrings=false&includeObsoleteEntities=false&tag_text=1") |>
#             		req_body_json(list(text = c("GLP-1-based therapies for diabetes, obesity and beyond",
#             				   "GPCR drug discovery: new agents, targets and indications"))) |>
#             		req_perform() |>
#             		resp_body_json()
# dummy_result_txt   <- dummy_result$text |> unlist() |> str_c(collapse = " | ")
# dummy_result_pos   <- dummy_result$entities |> map_vec(function(x) str_c(x[[1]], x[[2]], sep = " - ")) |> str_c(collapse = " | ")
# dummy_result_label <- dummy_result$entities |> map_vec(function(x) x[[3]]) |> str_c(collapse = " | ")
# dummy_result_onto  <- dummy_result$entities |> map_vec(function(x) x[[5]]) |> str_c(collapse = " | ")
# # So, the idea is to scale it:
# Ontologies to be used:
# Anatomical Entity Ontology 														AEO
# AI ontology				  														AIO
# Antibiotic Resistance Ontology													ARO
# BAO																				BAO
# Biomarker Ontology																BMONT
# The BRENDA Tissue Ontology 														BTO
# Cell Cycle Ontology																CCO
# Comparative Data Analysis Ontology												CDAO
# ChEBI ontology																	CHEBI
# chemical information ontology (cheminf) 										CHEMINF
# CHEBI Integrated Role Ontology													CHIRO
# Chemical Methods Ontology														CHMO
# Confidence Information Ontology													CIO
# Cell Ontology																	CL
# Cell Line Ontology																CLO
# Clinical Measurement Ontology													CMPO
# Core Ontology for Biology and Biomedicine										CBO
# Drug Ontology																	DRON
# Disease Drivers 																DISDRIV
# DIDEO																			DIDEO
# Experimental Factor Ontology													EFO
# Exposure Ontology																EXO
# Gene Expression Ontology														GEXO
# Medical Subject Headings														MESH
# Mathematical Modeling Ontology													MAMO
# Protein Modification															MOD
# Measurement Method Ontology														MMO
# Molecular Interactions Controlled Vocabulary									MI
# NCBI organismal classification													NCBITAXON
# Mass Spectrometry Ontology														MS
# Mondo Disease Ontology															MONDO
# Ontology for Biomedical Inv														OBI
# OAE: Ontology of Adverse Events													OAE
# Ontology for General Medical Science											OGMS
# Pathogen Host Interactions Phenotype Ontology   								PHIPO
# Symptom Ontology																SYMP
# Variation Ontology																VARIO
# TOXic Process Ontology (TXPO)                   								TXPO
# WikiPathways																	WIKIPATHWAYS
# Vaccine Ontology																VO
# Experimental condition ontology													XCO
# HUPO-PSI cross-linking and derivatization reagents controlled vocabulary		XLMOD
# The Unified Phenotype Ontology 									UPHENO
# NCI Thesaurus																		NCIT
# Divide the data into chunks of 50 and tag the corresponding titles

chunked_articles   <- articles |> mutate(id = row_number()) |>
					    	group_by(chunk_id = ceiling(row_number() / 100)) |>
							nest() |>
  							ungroup()
# Create the tibble to store the results
results <- tibble(text = rep(NA, nrow(chunked_articles)), pos = rep(NA, nrow(chunked_articles)),
	              labels = rep(NA, nrow(chunked_articles)), ontologies = rep(NA, nrow(chunked_articles)))

## Actually get the data
the_link       <- "https://www.ebi.ac.uk/ols4/api/v2/tag_text?ontologyId=aeo&ontologyId=aio&ontologyId=aro&ontologyId=bao&ontologyId=bmont&ontologyId=bto&ontologyId=cco&ontologyId=cdao&ontologyId=chebi&ontologyId=cheminf&ontologyId=chiro&ontologyId=chmo&ontologyId=cio&ontologyId=cl&ontologyId=clo&ontologyId=cmpo&ontologyId=cbo&ontologyId=dron&ontologyId=disdriv&ontologyId=dideo&ontologyId=efo&ontologyId=exo&ontologyId=gexo&ontologyId=mesh&ontologyId=mamo&ontologyId=mod&ontologyId=mmo&ontologyId=mi&ontologyId=ncbitaxon&ontologyId=ms&ontologyId=mondo&ontologyId=obi&ontologyId=oae&ontologyId=ogms&ontologyId=phipo&ontologyId=symp&ontologyId=vario&ontologyId=txpo&ontologyId=wikipathways&ontologyId=vo&ontologyId=xco&ontologyId=xlmod&ontologyId=ncit&ontologyId=upheno&delimiters=%20%7C%20&minLength=3&includeSubstrings=false&includeObsoleteEntities=false&tag_text=1"
n_times_waited <- 0
t_start <- Sys.time()
for (i in seq(1:nrow(results))) {
	# Make it a little safer
	api_status <- request("https://www.ebi.ac.uk/ols4/api/v2/tag_text?tag_text_status=1") |>
            		req_perform() |>
            		resp_body_json()
    if (isTRUE(api_status$available)) {
    	# API is OK, proceed
    	n_times_waited <- 0
    	# Try to get the data
    	tryCatch({
    		this_result <- request(the_link) |>
            		req_body_json(list(text = chunked_articles[[i,2]][1] |> unlist() |> str_c(collapse = " | "))) |>
            		req_perform() |>
            		resp_body_json()
          }, error = function(e){
            this_result <- list(text = c(NA), entities = list(list(start = NA,
            													   end = NA,
            													   term_label = NA,
            													   term_iri = NA,
            													   ontology_id = NA,
            													   string_type = NA)))
        })
    	results[i, 1]	<- this_result$text |> unlist() |> str_c(collapse = " | ")
    	results[i, 2]	<- this_result$entities |> map_vec(function(x) str_c(x[[1]], x[[2]], sep = " - ")) |> str_c(collapse = " | ")
		results[i, 3]	<- this_result$entities |> map_vec(function(x) x[[3]]) |> str_c(collapse = " | ")
		results[i, 4]	<- this_result$entities |> map_vec(function(x) x[[5]]) |> str_c(collapse = " | ")
    } else {
    	# API is not OK, wait or stop the whole thing
    	n_times_waited <- n_times_waited + 1
    	if (n_times_waited < 6) {
    		Sys.sleep(10)
    		# Repeat
    		i <- i - 1
    	} else {
    		break
    	}
    }
    Sys.sleep(5)
}
t_end <- Sys.time()
t_end - t_start

write_tsv(results, output)