# UHVDB/toolkit: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0.0dev - [date]

Initial release of UHVDB/toolkit, created with the [nf-core](https://nf-co.re/) template.

### `Added`

- Rewrite README.md from the original UHVDB/toolkit documentation
- LIFESTYLE subworkflow with BACPHLIP on new genomovar reps during `--run_update`; UHVDB_LIFESTYLE combiner is wired but waits on FUNCTION annotation outputs
- CRISPRHOST subworkflow with SpacerExtractor create/map modules, SPACER_DOWNLOAD from Kopah S3, and permanent Wave containers
- PHISTHOST subworkflow with UHBDB download, PHIST build/UHBDB modules, and host consensus annotation
- PHISTHOST sample-chunks large UHBDB AGCs (`params.phist_agc_split_min_bytes`) via PHIST_LISTSETS and extracts each chunk in-job inside PHIST_UHBDB (`params.phist_host_chunk_size`); smaller AGCs run PHIST_AGC without sample chunking
- UPDATE subworkflow that builds merged `uhvdb_metadata.tsv.gz` and `uhvdb_protein_annotations.tsv.gz`, and concatenates new plus existing ICTV, CRISPR, and PHIST hit tables

### `Changed`

- PHIST_UHBDB now takes an AGC plus a sample-name list and runs `agc getset` in-job instead of unpacking persistent host FASTA tarballs from PHIST_EXTRACTHOSTS

### `Fixed`

- PHIST_UHBDB extracts one gzipped FASTA per AGC sample (`agc getset -g 1`) instead of splitting contig headers into separate files; lower default `phist_host_chunk_size` (1000) and `maxForks` (10) to limit disk use

### `Dependencies`

### `Deprecated`
