# UHVDB/toolkit: Usage

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

UHVDB/toolkit has three modes, controlled by boolean flags (you may enable any combination):

- `--run_update` — classify, cluster, annotate, and publish next-release UHVDB tables under `<outdir>/uhvdb/`.
- `--run_analyze` — profile metagenomes against the current UHVDB release (sylph, PTH ratios, uninducible scores).
- `--run_assembly_analyze` — assemble and classify sample viruses, run mVIRs, Propagate, and vClust new2all, then annotate `REFERENCEACTIVITY` sylphmpa rows via reciprocal-best GANI hits.

Downloaded databases are cached under `--dbdir` (default: `databases`).

## Samplesheet input

```bash
--input '[path to samplesheet file]'
```

The samplesheet is a comma-separated file validated by [`assets/schema_input.json`](../assets/schema_input.json). Only `sample` is required; other columns are used depending on mode.

| Column | Description |
| ------ | ----------- |
| `sample` | Sample identifier (required; spaces become underscores). |
| `source_db` | Source database code (uppercase letters), e.g. `UHGV`, `ENA`. |
| `source_type` | `Assembly` or `Database` (update path). |
| `body_site` | `Gut`, `Airways`, `Skin`, `Urogenital`, `Blood`, or `Other`. |
| `project` | BioProject or study identifier. |
| `group` | Co-assembly / compare group label. |
| `biosample` | BioSample accession. |
| `acc` | SRA/ENA run accession (pipeline downloads reads when FASTQs are omitted). |
| `fastq_1` / `fastq_2` | Local gzipped FASTQ paths (`.fastq.gz` / `.fq.gz`). |
| `fna` | Assembly FASTA path or URL (optionally gzipped). |

Example update samplesheet:

```csv title="samplesheet.csv"
sample,source_db,source_type,body_site,group,acc,fastq_1,fastq_2,fna
uhgv_test_fna,UHGV,Database,Gut,,,,,https://github.com/UHVDB/toolkit/raw/refs/heads/master/assets/test_datasets/fna/uhgv_hq_plus_test.fna.gz
```

Example analyse samplesheet (SRA accession only):

```csv title="samplesheet.csv"
sample,project,group,biosample,acc,fastq_1,fastq_2,fna
N101S1,PRJNA530252,group1,SAMN11310209,SRR8834030,,,
```

Additional examples live under [`assets/test_datasets/samplesheet/`](../assets/test_datasets/samplesheet/).

## Running the pipeline

```bash
nextflow run UHVDB/toolkit \
  -profile docker \
  --input ./samplesheet.csv \
  --outdir ./results \
  --dbdir ./databases \
  --run_analyze
```

For database updates, add `--run_update` (and typically `--dtr_sequences_file` when classifying DTR viruses). For assembly-based mVIRs/Propagate/vClust signals linked to UHVDB species, add `--run_assembly_analyze` (this also runs assembly, classify, and reference analyse).

> [!WARNING]
> Provide pipeline parameters via the CLI or Nextflow `-params-file`. Custom config files with `-c` must not set parameters; see [nf-core docs](https://nf-co.re/docs/running/run-pipelines#using-parameter-files).

### Test profiles

| Profile | Purpose |
| ------- | ------- |
| `test` / `test_update` | Minimal update smoke test (`uhvdb_version=test`). Heavy on disk when downloads run. |
| `test_analyze` | Minimal analyse smoke test. |
| `test_update_full` | Larger update against full UHVDB v6 (HPC-oriented). |

Example:

```bash
nextflow run UHVDB/toolkit -profile test_analyze,docker --outdir ./results
```

### Updating the pipeline

```bash
nextflow pull UHVDB/toolkit
```

### Reproducibility

Pin a release with `-r <version>` from the [releases page](https://github.com/UHVDB/toolkit/releases).

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen).

### `-profile`

Generic profiles: `docker`, `singularity`, `podman`, `apptainer`, `conda`, `micromamba`, etc. Combine with a test profile, e.g. `-profile test_analyze,docker`.

If `-profile` is omitted, software must already be on `PATH` (not recommended).

### `-resume`

Resume from cached work directories. See the [Nextflow resume docs](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

### `-c`

Path to a custom Nextflow config (resources / executor only; not parameters).

## Custom configuration

See the [nf-core configuration docs](https://nf-co.re/docs/running/configuration/nextflow-for-your-system) for resource requests, containers, and tool arguments. An example institutional profile is [`conf/institutions/uw_hyak.config`](../conf/institutions/uw_hyak.config).

## Running in the background

Use Nextflow `-bg`, or `screen` / `tmux`, so the supervising Nextflow process keeps running after logout.

## Nextflow memory requirements

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

## Known limitations

- **Software versions in MultiQC** may be incomplete (process version collection is not fully wired yet).
- **`bin/phist` and `bin/xsra`** are prebuilt ELF binaries shipped with the pipeline; they are architecture-specific (typically Linux x86_64). Rebuild or replace them for other platforms.
- **GitHub Actions nf-test** is temporarily disabled pending CI rework.
