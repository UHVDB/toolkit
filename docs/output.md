# UHVDB/toolkit: Output

## Introduction

This document describes the output produced by the pipeline. Paths are relative to the top-level results directory (`--outdir`).

## Pipeline overview

- [UHVDB update](#uhvdb-update) — merged metadata and release tables from `--run_update`
- [Reference analyse](#reference-analyse) — metagenome profiling and activity scores from `--run_analyze`
- [Assembly analyse](#assembly-analyse) — mVIRs, Propagate, and vClust new2all from `--run_assembly_analyze`
- [MultiQC](#multiqc) — aggregate report
- [Pipeline information](#pipeline-information) — Nextflow and pipeline run reports

### UHVDB update

<details markdown="1">
<summary>Output files</summary>

- `uhvdb/`
  - `uhvdb_metadata.tsv.gz`: merged sequence metadata for the updated database, including BACPHLIP `virulent` / `temperate` scores and integration-related lifestyle columns when lifestyle annotation ran (`phrog_integrases`, `phrog_integration_excision`, `empathi_integration`).
  - `uhvdb_metadata_sylphtax.tsv.gz`: species-representative sylph-tax lineages (virus + host).
  - `uhvdb_protein_annotations.parquet`: merged per-protein annotations (parquet / zstd).
  - `uhvdb_proteins.faa.gz`: concatenated new unique + existing UHVDB proteins (when produced).
  - `uhvdb_genomovars_gani.tsv.gz` / `uhvdb_species_gani.tsv.gz`: combined GANI edges (when produced).
  - `uhvdb_proteinsimilarity.tsv.gz`: combined protein-similarity / normscore edges (when produced).
  - `uhvdb_ictv_hits.tsv.gz`: combined ICTV protein-similarity hits.
  - `uhvdb_crispr.parquet`: combined CRISPR spacer hits.
  - `uhvdb_phist.parquet`: combined PHIST host hits.

</details>

These files are produced when `--run_update` is set. Intermediate process directories are also published under `<outdir>/` by process name (default `publish_dir_mode` is `symlink`; release files under `uhvdb/` always use `copy`).

### Reference analyse

<details markdown="1">
<summary>Output files</summary>

- `uhvdb_toolkit/toolkit/referenceanalyze/uhvdb_referenceactivity/`
  - `*.sylphmpa`: per-sample sylph-tax profile with `virus_lifestyle`, `pth_ratio`, `ptr`, `uninducible_probability`, and `uninducible_tier` appended (alongside renamed base columns `ani`, `coverage`, and `virus_host`).
  - `*_reference_activity.tsv.gz`: per-sample inactive-virus scores for detected Caudoviricetes species representatives.
- Mega-module publish directories (`sracha_fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage` / `fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage`):
  - `*.profile.tsv`: sylph profile.
  - `*.depth.tsv.gz` / `*.gene_coverage.tsv.gz`: CoverM depth and gene coverage when contained viruses are present.
  - `*.output.tsv`: Pilea bacterial growth (PTR) profile against the GTDB sketch database.

</details>

These files are produced when `--run_analyze` is set and CoverM plus gene-coverage tables exist for a sample. The classifier is the figure_s15 Caudoviricetes story-20 random-forest model (`assets/models/phage_activity_model_full.joblib`). Class 1 is uninducible / inactive (bulk-detected, not enriched).

Lifestyle is Temperate when any genomovar in the species is integrated, has BACPHLIP temperate probability > 0.5, or carries an integration-related PHROG/Empathi gene; otherwise Virulent. PTH ratio is virus relative abundance divided by co-detected host abundance. `ptr` is the Pilea peak-to-trough ratio for co-detected bacterial species rows only.

### Assembly analyse

<details markdown="1">
<summary>Output files</summary>

- Mega-module publish directories (`sracha_fastp_deacon_mvirs_propagate_vclust` / `fastp_deacon_mvirs_propagate_vclust`):
  - `*.mvirs.fasta.gz`: mVIRs outward-facing paired-end / clipped-read virus sequences (empty when mVIRs is skipped).
  - `*.propagate.tsv.gz`: PropagAtE prophage-to-host coverage ratios from the mVIRs BAM (empty when no proviruses are present).
  - `*.ani.tsv.gz`: LZ-ANI new-to-all alignments of the sample's confident viruses against UHVDB species representatives (minimum 70% ANI and 20% query coverage).
  - `*.gani.tsv.gz`: query, reference, and gANI columns cut from the ANI table.
- `uhvdb_toolkit/toolkit/assemblyanalyze/uhvdb_assemblyactivity/`
  - `*.assemblyactivity.sylphmpa`: `REFERENCEACTIVITY` sylphmpa with `tr`, `mvirs`, and `propagate` columns filled for UHVDB species that have a reciprocal-best GANI hit to an assembled virus.

</details>

These files are produced when `--run_assembly_analyze` is set. Assembly, classify, and reference analyse also run in this mode. Reciprocal-best hits use maximum gANI (no extra cutoff). Each UHVDB species keeps a single strongest assembled virus. `tr` is `DTR` or `ITR` from classify topology (or CheckV completeness method); `mvirs` is `OPRs=<n>;HSs=<n>` from the parent contig; `propagate` is `prophage-host_ratio`. Rows without an RBH are `NA`.

### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: standalone HTML report.
  - `multiqc_data/`: parsed statistics.
  - `multiqc_plots/`: static images.

</details>

MultiQC summarises available QC and software metadata. Software version collection is currently incomplete (known limitation).

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Nextflow reports: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt`, `pipeline_dag.*`.
  - Pipeline reports when `--email` / `--email_on_fail` is set.
  - `samplesheet.valid.csv`, `params.json`, and software versions YAML when produced.

</details>
