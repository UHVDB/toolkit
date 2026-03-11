# UHVDB/toolkit

## Introduction
**UHMVB/toolkit** is a Nextflow pipeline for updating and utilizing the Unified Human Virome Database

## Databases

### Current database
| URL | Release     | Sequence count | Description | Samplesheet |
|-----|-------------|----------------|-------------|-------------|
| | 2026-03-13 | | Adds viruses from cystic fibrosis (CF) related MAGs and metagenomes | |

### Database history
| URL | Release     | Sequence count | Description | Samplesheet |
|-----|-------------|----------------|-------------|-------------|
| | 2026-03-12 | | Adds viruses from human airway, urogenital, and skin metagenome assemblies. | |
| | 2026-03-11 | | Adds viruses from 8 pre-existing human virus databases. | |
| | 2026-03-10 | | Initial release of UHVDB created from UHGV HQ+ confident & uncertain viruses. | |

## Pipeline Summary
Below is a schematic overview of the UHVDB toolkit. For a more detailed explanation of each step, see the [`SUMMARY.md`](/.github/SUMMARY.md) file.

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
