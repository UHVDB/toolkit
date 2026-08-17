# UHVDB/toolkit

[![Cite Publication](https://img.shields.io/badge/Cite%20Us!-Cite%20Publication-orange)](https://doi.org/10.64898/2026.05.01.722327)
[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.19831611-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.19831611)
[![Get help on Slack](http://img.shields.io/badge/slack-uhvdb-4A154B?labelColor=000000&logo=slack)](https://join.slack.com/t/uhvdb/shared_invite/zt-3x7msmig7-T1QMnbuZe2RAf_FBNIj_qg)
[![Open in GitHub Codespaces](https://img.shields.io/badge/Open_In_GitHub_Codespaces-black?labelColor=grey&logo=github)](https://github.com/codespaces/new/UHVDB/toolkit)
[![GitHub Actions CI Status](https://github.com/UHVDB/toolkit/actions/workflows/nf-test.yml/badge.svg)](https://github.com/UHVDB/toolkit/actions/workflows/nf-test.yml)
[![GitHub Actions Linting Status](https://github.com/UHVDB/toolkit/actions/workflows/linting.yml/badge.svg)](https://github.com/UHVDB/toolkit/actions/workflows/linting.yml)
[![nf-test](https://img.shields.io/badge/unit_tests-nf--test-337ab7.svg)](https://www.nf-test.com)

[![Nextflow](https://img.shields.io/badge/version-%E2%89%A525.10.4-green?style=flat&logo=nextflow&logoColor=white&color=%230DC09D&link=https%3A%2F%2Fnextflow.io)](https://www.nextflow.io/)
[![nf-core template version](https://img.shields.io/badge/nf--core_template-4.0.2-green?style=flat&logo=nfcore&logoColor=white&color=%2324B064&link=https://github.com/nf-core/tools/releases/tag/4.0.2)](https://github.com/nf-core/tools/releases/tag/4.0.2)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/UHVDB/toolkit)

> [!WARNING]
> UHVDB/toolkit is under active development and external testing. Singularity/Apptainer are currently recommended. Stay tuned for improved documentation and Conda/Mamba/Docker support.

## Introduction

**UHVDB/toolkit** is a Nextflow pipeline for updating and utilising the Unified Human Virome Database (UHVDB).

> UHVDB is a database containing 617,815 unique, high-quality viruses from human metagenomes that have been:
> - clustered
> - annotated with ICTV taxonomy
> - assigned predicted hosts
> - classified as temperate or virulent
> - functionally annotated
>
> The UHVDB/toolkit enables users to update UHVDB with new virus sequences. Additionally, the UHVDB/toolkit utilises UHVDB to taxonomically profile viruses in shotgun metagenomes with sylph, and uses CoverM to ensure high breadth of virus coverage.

## Databases

### Current database

| URL | Release | Description | Total | Unique | Genomovars | Species | Genera | Families | Proteins | Unique proteins |
|-----|---------|-------------|-------|--------|------------|---------|--------|----------|----------|-----------------|
| https://zenodo.org/records/19831612 | 5.0.0 | Adds viruses from cystic fibrosis (CF) related MAGs and metagenome assemblies | 816,318 | 617,815 | 535,799 | 206,289 | 43,125 | 1,446 | 35,366,004 | 15,539,600 |

<details>
<summary><h3>Database history</h3></summary>

| URL | Release | Description | Total | Unique | Genomovars | Species | Genera | Families | Proteins | Unique proteins |
|-----|---------|-------------|-------|--------|------------|---------|--------|----------|----------|-----------------|
| N/A | 4.0.0 | Adds viruses from human airway, urogenital, and skin metagenome assemblies. | 760,806 | 575,497 | 508,382 | 199,442 | 41,354 | 1,444 | 33,738,652 | 15,139,316 |
| N/A | 3.0.0 | Adds viruses from 9 pre-existing human virus databases. | 562,910 | 405,961 | 362,846 | 144,742 | 34,920 | 1,247 | 24,756,438 | 10,948,333 |
| N/A | 2.0.0 | Adds HQ+ uncertain viruses from UHGV. | 204,088 | 181,979 | 158,727 | 54,296 | 18,885 | 839 | 11,589,486 | 4,972,070 |
| N/A | 1.0.0 | Initial release of UHVDB created from UHGV HQ+ confident viruses. | 201,324 | 179,392 | 156,387 | 53,595 | 18,547 | 815 | 11,195,711 | 4,911,827 |

</details>

## Pipeline summary

Below is a schematic overview of the UHVDB toolkit, followed by a brief explanation of each workflow in the toolkit.

![UHVDB toolkit schematic](assets/uhvdb-diagram.png)

<details>
<summary><h3>UHVDB update subworkflow descriptions</h3></summary>

1. PREPROCESS
> - Reads are downloaded using [sracha](https://github.com/EBI-Metagenomics/sracha), preprocessed with [fastp](https://github.com/OpenGene/fastp), and human reads are removed with [deacon](https://github.com/bede/deacon).
2. ASSEMBLE
> - Read sets from the same co-assembly group are concatenated and assembled using [MEGAHIT](https://github.com/voutcn/MEGAHIT).
3. CLASSIFY
> - Assemblies are length filtered (>= 2 kbp) with [seqkit](https://github.com/shenwei356/seqkit) and run through [geNomad](https://github.com/apcamargo/genomad). Then, sequences having a virus score < 0.7, no assigned ICTV class, or < 10 kbp (for Caudoviricetes) are removed. Inoviridae-specific filters (no minimum virus score and length between 4.5 - 12.5 kbp) are also used.
> - After geNomad filtering, sequences are run through [CheckV](https://bitbucket.org/berkeleylab/checkv/src/master/), and only sequences with an AAI-completeness >= 50%, a kmer frequency <= 1.2, and an AAI-completeness <= 150% are retained.
> - After CheckV filtering, sequences are run through [viralVerify](https://github.com/ablab/viralVerify), and results from geNomad, CheckV, and viralVerify are combined to assign a hybrid score to each sequence (>= 2: confident virus; 0-1: uncertain virus; < 0: non-viral).
4. HQFILTER
> - DTR viruses (confident and uncertain) have their DTRs trimmed using [tr-trimmer](https://github.com/apcamargo/tr-trimmer), then are dereplicated and aligned to CheckV's database using [vClust](https://github.com/refresh-bio/vclust). Then, sequences representing a novel species (< 95% ANI or < 85% AF) are added to CheckV's database.
> - After updating CheckV's database with novel DTRs, CheckV is re-run on all viruses. Only high-quality viruses (>= 90% AAI-completeness) are retained.
5. HCFILTER
> - High-quality viruses characterised as "uncertain" are searched against geNomad's database of virus and plasmid hallmark genes using [HMMER](https://github.com/EddyRivasLab/hmmer). Only sequences having >= 3 virus hallmarks and 0 plasmid hallmarks are re-classified as "confident" viruses.
6. DEREPLICATE
> - High-quality, confident viruses are dereplicated into unique sequences with [seq-hasher](https://github.com/apcamargo/seq-hasher). Sequences sharing a hash with a previous UHVDB sequence are not analysed any further, while new sequences are assigned a new ID with the pattern `UHVDB-*`.
> - Pairwise alignments for all new and previous unique UHVDB sequences are performed with vClust. Only alignments with >= 99.5% ANI and 100% AF are retained, and input into [MCL](https://github.com/micans/mcl) for genomovar clustering. The longest DTR is selected as the genomovar representative. When no DTR is present, the sequence with the most CheckV viral genes (tiebreaker being the closest to CheckV's expected length) is chosen as the representative.
7. ANICLUSTER
> - Pairwise alignments for all new and previous genomovar representatives are performed with vClust, filtered to retain only those with >= 95% ANI and 85% AF, and clustered into species with MCL. Representatives are chosen in the same manner as for genomovars.
8. AAICLUSTER
> - ORFs are predicted from species representatives using [pyrodigal-gv](https://github.com/althonos/pyrodigal-gv). Then, pairwise alignments for all proteins from new and old species representatives are performed with [DIAMOND](https://github.com/bbuchfink/diamond).
> - Self-scores are calculated by summing the bitscores from all self-alignments. Protein similarity values are calculated by dividing the summed bitscore for a genome pair by the self score.
> - All pairwise protein similarity values >= 5.5 are input into MCL to cluster the dataset at the family level. Then, intra-family genome pairs are filtered to only those having >= 32% protein similarity, which are then clustered at the subfamily level. This is repeated for the genus (65% protein similarity) and subgenus (80% protein similarity) levels.
9. TAXONOMY
> - ICTV sequences are downloaded using [ICTVtaxablast](https://github.com/ICTV-Virus-Knowledgebase/ICTVtaxablast) and ORFs are predicted with pyrodigal-gv.
> - ORFs are predicted from UHVDB genomovar representatives and aligned to ICTV ORFs using DIAMOND. Protein similarity values are calculated as described in the AAICLUSTER subworkflow.
> - The taxonomy of the ICTV genome with the highest protein similarity is assigned to each genomovar representative if the protein similarity.
10. CRISPRHOST
> - CRISPR spacers from SPIRE and proGenomes3 (hosted on Kopah S3) are aligned to UHVDB genomovar representatives using [SpacerExtractor](https://code.jgi.doe.gov/SRoux/spacerextractor) requiring <= 1 mismatch across the length of the spacer.
> - Then, the lowest host rank having >= 70% agreement across all CRISPR connections is identified.
11. PHISTHOST
> - MAGs from human samples in [mOTUs-DB](https://motus-db.org) and isolates assigned to the same genera as these MAGs are searched for genomovar representative containment using [PHIST](https://github.com/refresh-bio/PHIST).
> - Then, the lowest host rank having >= 70% agreement across all PHIST connections is identified.
12. FUNCTION
> - ORFs from all genomovar representatives are predicted using pyrodigal-gv.
> - To link proteins to UniProt/InterPro IDs, these ORFs are annotated using [Bakta](https://github.com/oschwengers/bakta) with an additional DIAMOND search against [UniRef50](https://www.uniprot.org/help/uniref) representatives having a virus taxonomy. ORFs having < 30% AAI or < 80% bidirectional coverage to a Bakta/UniRef50 protein are searched against [BFVD](https://bfvd.foldseek.com), the [viral AlphaFold database](https://vad.atkinson-lab.com), and [vFOLD](https://vogdb.org) using [Foldseek](https://github.com/steineggerlab/foldseek). ORFs having a Foldseek bidirectional coverage < 90% are run through [InterProScan](https://github.com/ebi-pf-team/interproscan).
> - To link proteins to phage-specific functions, all ORFs are analysed using [pharokka](https://github.com/gbouras13/pharokka). Those unannotated by pharokka are run through [Phold](https://github.com/gbouras13/phold). Additionally, all ORFs are run through [EmPATHi](https://huggingface.co/AlexandreBoulay/EmPATHi).
13. LIFESTYLE
> - Unique sequences are designated as integrated or unintegrated using geNomad and CheckV. Then, [BACPHLIP](https://github.com/adamhockenberry/bacphlip) is run on all genomovar representatives. Finally, each genomovar representative is analysed for the presence of an integration-related PHROG/EmPATHi protein.
14. UPDATE
> - Outputs from all subworkflows and the prior UHVDB release are combined into merged metadata and protein annotation tables, plus concatenated ICTV, CRISPR, and PHIST hit tables, and published to `<outdir>/uhvdb/`.

</details>

<details>
<summary><h3>Analysis subworkflow descriptions</h3></summary>

1. REFERENCEANALYZE
> - Reads are downloaded (when an SRA accession is provided) using sracha, preprocessed with fastp, and human reads are removed with deacon.
> - Reads are taxonomically profiled using [sylph](https://github.com/bluenote-1577/sylph), with UHVDB and GTDB species representatives as references. Then, reads are aligned to detected UHVDB genomes using [CoverM](https://github.com/wwood/CoverM), and gene coverage is calculated from protein annotations.

</details>

## Quick start

If you are new to Nextflow and nf-core, see the [environment setup overview](https://nf-co.re/docs/get_started/environment_setup/overview).

1. Install micromamba

```bash
"${SHELL}" <(curl -L micro.mamba.pm/install.sh)
```

2. Create and activate a Nextflow environment

```bash
micromamba create -n nextflow -c conda-forge -c bioconda nextflow=25.10.4 -y
micromamba activate nextflow
```

3. Run the `test_analyze` profile to test metagenome analysis with UHVDB.

Navigate to a directory with at least 10 GB of disk available.

```bash
# activate nextflow environment
micromamba activate nextflow

# create a new directory where disk is available
# (<target_dir> = a new directory; i.e. `/gscratch/pedslabs_hoffman/carsonjm/TEST/`)
mkdir -p <target_dir>

# navigate to a new directory
cd <target_dir>

# run the pipeline
# `singularity` can be replaced with an institutional profile (i.e. `uw_hyak`)
nextflow run UHVDB/toolkit -profile singularity,test_analyze -latest --outdir <OUTDIR>
```

4. Run the `test_update` profile to test adding viruses to UHVDB.

```bash
nextflow run UHVDB/toolkit -profile singularity,test_update -latest --outdir <OUTDIR>
```

> [!WARNING]
> Provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration except for parameters. See the [nf-core docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

## User guides for the UHVDB/toolkit

This section describes how to use the UHVDB/toolkit to (1) update UHVDB and (2) analyse metagenomes with UHVDB.

> [!WARNING]
> Adding new sequences to UHVDB is very compute intensive. Only do this if you have access to an HPC. Our team is planning to update UHVDB periodically, particularly when other virus databases are released.

<details>
<summary><h3>User guide for updating UHVDB</h3></summary>

1. Create an input samplesheet
> This step can be variable. For example, if you want to mine a pre-existing virus database FASTA and add those sequences to UHVDB, the samplesheet can be as simple as:
>
> ```csv
> sample,source_db,source_type,body_site,project,group,biosample,acc,fastq_1,fastq_2,fna
> uhgv,UHGV,Database,Gut,uhgv,uhgv,,,,https://portal.nersc.gov/UHGV/genome_catalogs/uhgv_hq_plus.fna.gz
> ```
>
> However, for mining thousands of metagenomes, things can get much more complicated. These [example scripts](assets/scripts/mining-setup-scripts.ipynb) can be used as inspiration, and the samplesheet will likely look something like this:
>
> ```csv
> sample,source_db,source_type,body_site,project,group,biosample,acc,fastq_1,fastq_2,fna
> SRR16355214,LOGAN,Assembly,,uhvdb_update,uhvdb_update,,,,,s3://logan-pub/c/SRR16355214/SRR16355214.contigs.fa.zst
> SRR17255824,LOGAN,Assembly,,uhvdb_update,uhvdb_update,,,,,s3://logan-pub/c/SRR17255824/SRR17255824.contigs.fa.zst
> SRR18707710,LOGAN,Assembly,,uhvdb_update,uhvdb_update,,,,,s3://logan-pub/c/SRR18707710/SRR18707710.contigs.fa.zst
> SAMEA3914866,SPIRE,Assembly,,uhvdb_update,uhvdb_update,,,,,https://spire.embl.de/download_assembly/SAMEA3914866
> SAMEA3914864_1,SPIRE,Assembly,,uhvdb_update,uhvdb_update,,,,,https://spire.embl.de/download_assembly/SAMEA3914864
> SAMEA3914864_2,SPIRE,Assembly,,uhvdb_update,uhvdb_update,,,,,https://spire.embl.de/download_assembly/SAMEA3914864
> ERZ1022850,ENA,Assembly,Gut,uhvdb_update,uhvdb_update,,,,,https://ftp.sra.ebi.ac.uk/vol1/sequence/ERZ102/ERZ1022850/contig.fa.gz
> ERZ1022851,ENA,Assembly,,uhvdb_update,uhvdb_update,,,,,https://ftp.sra.ebi.ac.uk/vol1/sequence/ERZ102/ERZ1022851/contig.fa.gz
> ERZ1022855,ENA,Assembly,,uhvdb_update,uhvdb_update,,,,,https://ftp.sra.ebi.ac.uk/vol1/sequence/ERZ102/ERZ1022855/contig.fa.gz
> SAMD00002817,ATB,Assembly,,uhvdb_update,uhvdb_update,,,,,s3://allthebacteria-assemblies/SAMD00002817.fa.gz
> SAMD00003131,ATB,Assembly,,uhvdb_update,uhvdb_update,,,,,s3://allthebacteria-assemblies/SAMD00003131.fa.gz
> SAMN35363042,ATB,Assembly,Skin,uhvdb_update,uhvdb_update,,,,,s3://allthebacteria-assemblies/SAMN35363042.fa.gz
> .
> .
> .
> <thousands of rows here>
> ```
>
> `source_type` must be `Assembly` or `Database`. Optional `body_site` values are `Gut`, `Airways`, `Skin`, `Urogenital`, or `Other`.

2. Create an institutional config file
> To run this pipeline on an HPC, you should make an institutional profile. This file will specify the executor, queue, partition, and related settings that Nextflow will use on your HPC. We provide an [example profile](./conf/institutions/uw_hyak.config), and many more examples can be found on [nf-core](https://github.com/nf-core/configs/tree/master/conf).

3. Run the pipeline
> After creating the samplesheet and config file, you can run the update pipeline as follows:
> ```bash
> nextflow run UHVDB/toolkit \
>   -r main \
>   -latest \
>   -c <path_to_config_file> \
>   --input <path_to_samplesheet> \
>   --outdir <path_to_output_dir> \
>   --dbdir <path_to_where_databases_will_be_stored> \
>   --run_update
> ```
> This command will automatically download databases and Singularity/Apptainer containers, and create the files for an updated UHVDB database.
>
> **If you have already run the pipeline, re-use the existing `--dbdir`. It will save a lot of time and about 300 GB of disk.**

4. Ensure that all necessary output files have been created.
> `--run_update` currently publishes the following files to `<outdir>/uhvdb/`:
> 1. `uhvdb_metadata.tsv.gz`: merged sequence metadata for the updated database.
> 2. `uhvdb_protein_annotations.tsv.gz`: merged per-protein annotations.
> 3. `uhvdb_ictv_hits.tsv.gz`: combined new and existing ICTV protein-similarity hits.
> 4. `uhvdb_crispr.tsv.gz`: combined new and existing CRISPR spacer hits.
> 5. `uhvdb_phist.tsv.gz`: combined new and existing PHIST host hits.
>
> Intermediate output files created by this pipeline are stored under `<outdir>/` by process name.

5. Request to add the updated database to the [UHVDB Zenodo community](https://zenodo.org/communities/uhvdb/records?q=&l=list&p=1&s=10&sort=newest)
> 1. Download the above UHVDB files locally.
> 2. Go to the [UHVDB Zenodo community](https://zenodo.org/communities/uhvdb/records?q=&l=list&p=1&s=10&sort=newest). Create a Zenodo account if you do not have one.
> 3. Press the green **New upload** button.
> 4. Add each UHVDB file via drag and drop or the **Upload files** button.
> 5. Fill out metadata fields to the best of your ability (these can be changed later).
> 6. Once the files have been uploaded and the fields filled out, press the blue **Submit for review** button.
> 7. Send an email to `carsonjm@uw.edu`, post in the [Slack](https://join.slack.com/t/uhvdb/shared_invite/zt-3x7msmig7-T1QMnbuZe2RAf_FBNIj_qg), create a [GitHub issue](https://github.com/UHVDB/toolkit/issues/new/choose) in UHVDB/toolkit, or all three to get an administrator to review the request.

</details>

<details>
<summary><h3>User guide for metagenome analyses</h3></summary>

1. Create an input samplesheet
> To create an analysis samplesheet, you must have a sample ID and either FASTQ files or an SRA Run Accession ID (for example `SRR16355214`). An assembly FASTA file can also be included if available. Below is an example samplesheet.
>
> ```csv
> sample,project,group,biosample,acc,fastq_1,fastq_2,fna
> N101S0,PRJNA530252,group1,SAMN11310208,SRR8834029,,,
> N101S1,PRJNA530252,group1,SAMN11310209,SRR8834030,,,
> N101S2,PRJNA530252,group1,SAMN11310210,SRR8834031,,,
> N101S3,PRJNA530252,group1,SAMN11310211,SRR8834032,,,
> N101S4,PRJNA530252,group1,SAMN11310212,SRR8834033,,,
> ```
>
> If you want to perform co-assembly or run inStrain compare on groups of samples, the `group` field must also be included.

2. Create an institutional config file
> To run this pipeline on an HPC, you should make an institutional profile. This file will specify the executor, queue, partition, and related settings that Nextflow will use on your HPC. We provide an [example profile](./conf/institutions/uw_hyak.config), and many more examples can be found on [nf-core](https://github.com/nf-core/configs/tree/master/conf).

3. Run the pipeline
> After creating the samplesheet and config file, you can run the analysis pipeline as follows:
> ```bash
> nextflow run UHVDB/toolkit \
>   -r main \
>   -latest \
>   -c <path_to_config_file> \
>   --input <path_to_samplesheet> \
>   --outdir <path_to_output_dir> \
>   --dbdir <path_to_where_databases_will_be_stored> \
>   --run_analyze
> ```
> This command will automatically:
> 1. download and preprocess reads
> 2. taxonomically profile reads with sylph and CoverM
> 3. calculate gene coverage for detected UHVDB genomes

4. Analyse the outputs
> After the pipeline has completed, sylph profiles, CoverM depth tables, gene-coverage tables, and merged sylph-tax reports are written under `<outdir>/` by process name.

</details>

## Future goals

<details>
<summary><h3>In progress</h3></summary>

- Add human-environment HQ+ viruses from [metaVR](https://doi.org/10.1093/nar/gkaf1283) and [VIRE](https://doi.org/10.1093/nar/gkaf1225) to UHVDB
- Wire ASSEMBLYANALYZE: align reads to associated assemblies and analyse prophage excision/circularisation with [mVIRs](https://github.com/SushiLab/mVIRs), determine elevated prophage coverage with [PropagAtE](https://github.com/AnantharamanLab/PropagAtE), and link assemblies to UHVDB species with vClust
- Add co-assembly functionality to ASSEMBLYANALYZE and benchmark recovery vs single-sample assembly
- Assign UHVDB species activity confidence tiers with a random forest classifier (reference-only and assembly-aware feature sets)

</details>

<details>
<summary><h3>Low-hanging fruit (days - weeks)</h3></summary>

- Add detected bacterial species to CoverM alignment
- Add inStrain profile and inStrain compare within co-assembly groups
- Add Pilea to estimate bacterial growth rate via peak-to-trough (PTR)
- Add iPHoP for genomovar reps not having a PHIST or spacer host prediction
- Use vCONTACT3 for taxonomic classification
- Add DGRscan (ideally a more efficient Python 3 version)
- Add DefenseFinder and dbAPIs to protein annotations
- Add Docker/Mamba/Conda functionality to the entire pipeline
- Update pipeline to adhere to Nextflow 26.04 syntax
- Investigate genomovar-level profiling (use genomovar reps in sylph/CoverM instead of species reps)
- Update UHBDB to include HRGM2, HROM, and SPIRE genomes
    - Update GTDB taxonomic assignments to r232 with skani

</details>

<details>
<summary><h3>Ambitious goals (weeks - months)</h3></summary>

- Add RNA viruses to UHVDB
    - ICTV class-specific clustering and annotation workflows?
- Investigate other signals of virus activity
    - Number of virus hallmarks/structural genes and their dN/dS relative to known active viruses (https://www.nature.com/articles/s41586-025-09614-7)
    - Presence of CRISPR spacer in short reads targeting UHVDB virus or assembled virus (https://doi.org/10.1101/2025.06.12.659409)
    - Presence of a virus species (or genomovar) in a highly-enriched dataset (https://doi.org/10.1101/2024.02.19.580813)
- Identify CRISPR spacers in all UHBDB genomes
- Make pipeline adhere to nf-core guidelines as closely as possible
- Add nf-tests to pipeline

</details>

## Credits

UHVDB/toolkit was originally written by [Carson Miller](https://github.com/CarsonJM) at the [University of Washington](https://www.washington.edu/).

## Contributions and Support

If you would like to contribute to this database/pipeline, please join the [Slack](https://join.slack.com/t/uhvdb/shared_invite/zt-3x7msmig7-T1QMnbuZe2RAf_FBNIj_qg), post in the [GitHub Discussions](https://github.com/UHVDB/toolkit/discussions), or create a [GitHub Issue](https://github.com/UHVDB/toolkit/issues). See also the [contributing guidelines](docs/CONTRIBUTING.md).

## Citations

If you use UHVDB/toolkit for your analysis, please cite it using the following doi: [10.5281/zenodo.19831611](https://doi.org/10.5281/zenodo.19831611).

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
