# UHVDB/toolkit
**Unified Human Virus Database** toolkit

## Introduction
**UHMVB/toolkit** is a Nextflow pipeline for consolidating and expanding human virome databases in a consistent, high-confidence mann

## Databases

### Current database
| Database | Release     | Sequence count | Description | Samplesheet |
|----------|-------------|----------------|-------------|-------------|
| UHVDB | 2026-03-13 | | Adds viruses from cystic fibrosis (CF) related MAGs and metagenomes | |

### Database history
| Database | Release     | Sequence count | Description | Samplesheet |
|----------|-------------|----------------|-------------|-------------|
| UHVDB | 2026-03-12 | | Adds viruses from human airway, urogenital, and skin metagenome assemblies. | |
| UHVDB | 2026-03-11 | | Adds viruses from 8 pre-existing human virus databases. | |
| UHVDB | 2026-03-10 | | Initial release of UHVDB created from UHGV HQ+ confident & uncertain viruses. | |

## Pipeline Summary

### PREPROCESS (accession/FASTQ -> preprocessed FASTQ)
- If only an SRA accession is provided, the FASTQ files downloaded with [xsra](https://github.com/ArcInstitute/xsra)
- Local and downloaded FASTQs are then QC'd using [fastp](https://github.com/OpenGene/fastp)
- Human reads are removed using [deacon](https://github.com/bede/deacon)
- FASTQs are compressed using [spring](https://github.com/shubhamchandak94/Spring)

### ASSEMBLE (FASTQ -> FASTA)
- FASTQs are assembled using [megahit](https://github.com/voutcn/megahit)
- Contigs shorter than 2,000 bp are removed, and remaining contigs are renamed using sample IDs [seqkit](https://github.com/shenwei356/seqkit)

### UHVDB
**CLASSIFY (FASTA -> medium-quality viruses )**
- If FASTA paths are a URL, the fasta will be downloaded using [aria2](https://github.com/aria2/aria2)
- Contigs shorter than 2,000 bp are removed and remaining contigs are renamed using seqkit
- Virus sequences are identified using [geNomad](https://github.com/apcamargo/genomad/) with the `--relaxed` option
- Low-confidence/completeness viruses (virus score < 0.7, no Class assignment, Caudoviricetes , 10,000 bp) are removed from geNomad's output using [csvtk](https://github.com/shenwei356/csvtk) and seqkit
- Passing viruses are run through [CheckV](https://bitbucket.org/berkeleylab/CheckV/src/master/), and low-quality viruses (AAI-completeness < 50%, kmer_freq > 1.2, contig length > 1.5x expected length) are removed
- Passing viruses are run through [viralVerify](https://github.com/ablab/viralVerify)
- Sequences are labeled as `non-viral`, `confident`, or `uncertain` using the criteria established in [UHGV](https://doi.org/10.1101/2025.11.01.686033) and `non-viral` sequences are removed

**HQFILTER (medium-quality viruses -> high-quality viruses)**
- Viruses having direct terminal repeats (DTRs) are extracted and DTRs are trimmed using [tr-trimmer](https://github.com/apcamargo/tr-trimmer)
- Trimmed DTR-viruses are dereplicated at 95% ANI and 85% AF using [vClust](https://github.com/refresh-bio/vclust)
- Dereplicated DTR-viruses are aligned to CheckV's database of complete virus genomes using a modified version of vClust
- DTR-viruses with < 95% ANI or < 85% AF are added to CheckV's database
- All `confident` and `uncertain` viruses output by the **CLASSIFY** subworkflow are run through CheckV's completeness module using the updated database
- Sequences with < 90% AAI completeness are removed

**HCFILTER (high-quality viruses -> high-quality, high-confidence genomovar reps)**
- Sequence hashes are computed for high-quality viruses using [seq-hasher](https://github.com/apcamargo/seq-hasher) and dereplicated to one sequence per hash
- High-quality viruses are clustered at the genomovar level (99.5% ANI and 100% AF) using vClust and [MCL](https://github.com/micans/mcl) with representatives selected based on DTR topology, virus gene count, and the difference between expected and actual genome length
- Genomovar representatives classified as `uncertain` viruses are searched against geNomad's database of virus and plasmid hallmarks using [HMMER](https://github.com/EddyRivasLab/hmmer)
- High-quality `uncertain` gnomovars with >= 3 virus hallmarks and 0 plasmid hallmarks are combined with high-quality `confident` genomovars

**ANICLUSTER (genomovar reps ->  species reps)**
- High-quality, high-confidence genomovars are clustered at the species level (95% ANI and 85% AF) using vClust and MCL with representatives selected based on DTR topology, virus gene count, and the difference between expected and actual genome length

**AAICLUSTER (species reps -> family, subfamily, genus, subgenus cluster assignments)**
- High-quality, high-confidence genomovars are clustered at the species level (95% ANI and 85% AF) using vClust and [MCL](https://github.com/micans/mcl)

**TAXONOMY (genomovar reps -> virus taxonomy)**
- International Committee on Taxonomy of Viruses ([ICTV](https://ictv.global/)) sequences are downloaded using [ICTVTaxaBlast](https://github.com/ICTV-Virus-Knowledgebase/ICTVtaxablast)
- Virus genes are predicted using [pyrodigal-gv](https://github.com/althonos/pyrodigal-gv) and used to create a [DIAMOND](https://github.com/bbuchfink/diamond) database
- Genomovar reprs are run through pyrodigal-gv and aligned to ICTV genes using DIAMOND
- Normalized genome-wide proteomic similarity is calculated using a modified version of [UHGV-classifier](https://github.com/snayfach/UHGV-classifier)
- Class assignments using geNomad marker genes and ICTV family-assignments (for viruses having >= 5.5% protein similarity to an ICTV virus) are combined 

**HOSTPREDICTION (genomovar reps -> virus host)**
- Genomovar reps are compared to UHBDB genomes using [PHIST](https://github.com/refresh-bio/PHIST)
- Genomovar reps are compared to CRISPR spacers created from [VIRE](https://doi.org/10.1093/nar/gkaf1225)

**FUNCTION (genomovar reps -> UniProt, PHROG, Empathi, CARD, VFDB, and DefenseFinder annotations)**
- Protein sequences are predicted for genomovar reps using pyrodigal-gv and dereplicated using seqkit
- Dereplicated protein sequences are assigned to UniProt/InterPro IDs using [Bakta](https://github.com/oschwengers/bakta), [foldseek](https://github.com/steineggerlab/foldseek), and [InterProScan](https://github.com/ebi-pf-team/interproscan)
- Dereplicated protein sequences are assigned to phage-functional categories using [Pharokka](https://github.com/gbouras13/pharokka), [Phold](https://github.com/gbouras13/phold), and [Empathi](https://huggingface.co/AlexandreBoulay/EmPATHi)
- Dereplicated protein sequences are aligned to [CARD](https://card.mcmaster.ca/), [VFDB](https://www.mgc.ac.cn/VFs/main.htm), and [DefenseFinder](https://github.com/mdmparis/defense-finder)

**LIFESTYLE (genomovar reps -> lifestyle prediction)**
- Genomovar reps are classified as virulent or temperate using [BACPHLIP](https://github.com/adamhockenberry/bacphlip)
- Genomovar reps are classified as temperate if they contain integrase/recombinase genes identified via Pharokka or Phold
- Genomovars are classified as temperate if they contain an integrated provirus
- (COMING SOON) genomovar reps are classified as temperate if they contain Empathi integration genes or Pharokka/Phold Integration/Excision genes

**UPDATE (high-quality, high-confidence genomovars + annotations -> updated UHVDB version)**
- New sequence hashes are added to UHVDB
- New genomovar reps and their annotations are added to UHVDB
- New species reps and their annotations (majority for taxonomy/host and temperate if > 0 temperate genomovar) are added to UHVDB
- The UHVDB species alignment file is updated with new genome alignments so that these do not need to be repeated
- The UHVDB protein similarity file is updated with new genome alignments so that these do not need to be repeated

**REFERENCEANALYZE (reads + UHVDB -> taxonomic profile + reference-based activity score)**
- Reads are taxonomically profiled using [sylph](https://github.com/bluenote-1577/sylph)
- Species representatives detected via sylph are extracted, and reads are aligned to these representatives using [Coverm](https://github.com/wwood/CoverM)
- A reference-based activity score is calculated based on breadth of coverage, DTR topology, and virus lifestyle
- (COMING SOON) Virus microdiversity is calculated within and between samples using [inStrain](https://github.com/MrOlm/instrain)

**ASSEMBLYANALYZE (subworkflow)**
- Sample-specific assemblies are aligned to UHVDB using a modified vClust
- Elevated coverage of provirus regions relative to surrounding bacterial regions is determined using [PropagAtE](https://github.com/AnantharamanLab/PropagAtE) on sample-specific provirus assemblies
- Prophage circularization is identified using [mVIRs](https://github.com/SushiLab/mVIRs) to identify outward paired reads (OPRs) and split reads (SRs) when mapping to sample-specific virus assemblies
- An assembly-based activity score is calculated based on a DTR virus assembly, elevated provirus coverage, and OPR/SR detection

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

```bash
nextflow run UHVDB/toolkit -profile <singularity/institute>,test
```

> [!WARNING]
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_; see [docs](https://nf-co.re/docs/usage/getting_started/configuration#custom-configuration-files).

For more details and further functionality, please refer to the [`USAGE.md`](/.github/USAGE.md) and [`PARAMETERS.md`](/.github/PARAMETERS.md) files.

## Outputs

For details about the output files and reports, please refer to the [`OUTPUT.md`](/.github/OUTPUT.md) file.

## Future goals

### Low-hanging fruit (days to weeks to implement)
- Add human-environment HQ+ viruses from [metaVR](https://doi.org/10.1093/nar/gkaf1283) and [VIRE](https://doi.org/10.1093/nar/gkaf1225) to UHVDB
- Add co-assembly functionality to ASSEMBLYANALYZE and benchmark recovery vs single-sample assembly
- Add instrain/profile + inStrain/compare within co-assembly groups
- Run iPHoP on genomovar reps without a PHIST/spacer host
- Use vCONTACT3 for taxonomic classification
- Add DGRscan (ideally a more efficient Python3 version)
- Add Docker/mamba/conda functionality to pipeline

### Stretch goals (weeks to months to implement)
- Add RNA viruses to UHVDB
    - Class-specific clustering and annotation
- Investigate genomovar-level profiling
    - sylph (to prescreen contained genomovars) + CoverM (to determine breadth of coverage)
- Improve lifestyle prediction
    - Use complete integrated proviruses without identified integrase to find other Empathi/Phold signals (https://www.nature.com/articles/s41586-025-09786-2)
- Investigate other signals of virus activity
   - Number of virus hallmarks/structural genes and their dN/dS relative to known active viruses (https://www.nature.com/articles/s41586-025-09614-7)
   - Presence of CRISPR spacer in short reads targeting UHVDB virus or assembled virus (https://doi.org/10.1101/2025.06.12.659409 )
   - Presence of a virus species (or genomovar) in a highly-enriched dataset (https://doi.org/10.1101/2024.02.19.580813)
- Add nf-tests to pipeline

## Contributions and Support

If you would like to contribute to this pipeline, please see the [`CONTRIBUTING.md`](.github/CONTRIBUTING.md) file.

## Credits

UHVDB/toolkit was originally written by [Carson Miller](https://github.com/CarsonJM) at the [University of Washington](https://www.washington.edu/).

## Citations

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
