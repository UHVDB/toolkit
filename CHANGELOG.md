# UHVDB/toolkit: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## 1.1.0 [2026.09.04]

### `Added`
- Added Pilea to calculate peak-to-trough (PTR) ratios during the `REFERENCEANALYZE` subworkflow (`--run_analyze`)
- Added a beta version of an `ASSEMBLYANALYZE` subworkflow (`--run_assembly_analyze`). This subworkflow is an attempt to capture the following evidence of phage activity from assembled phage sequences: 1) hard/soft clipped reads, 2) outward-facing paired ends, 3) propagate phage-to-host ratios, 4) direct/inverted terminal repeats. Then, these will be linked to UHVDB species representatives (detected in `REFERENCEANALYZE`) using reciprocal-best-hits.

### `Changed`
- Hard-coded sylph sketch arguments (`-i -c 200`) into SYLPH_SKETCHGENOMES module.

### `Fixed`

### `Dependencies`

### `Deprecated`


## 1.0.0 [2026.08.26]

Initial release of the updated UHVDB/toolkit, created using the [nf-core](https://nf-co.re/) template.

### `Added`

### `Changed`

### `Fixed`

### `Dependencies`

### `Deprecated`
