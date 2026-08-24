process UHVDB_CONCATPHIST {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b8/b80c0153f3740c99d626acdb271cc7c62e220ff17d8f8421493aa6365c08038e/data':
        'community.wave.seqera.io/library/pysam_numpy_polars:ffb596c8bdfe2ed8' }"

    input:
    tuple val(meta), path(files_in, stageAs: 'to_concatenate/*', arity: '1..*')

    output:
    tuple val(meta), path("uhvdb_phist.parquet"), emit: parquet

    script:
    """
    uhvdb_concat_phist.py \\
        to_concatenate/* \\
        --output uhvdb_phist.parquet
    """

    stub:
    """
    python -c "import polars as pl; pl.DataFrame({'uhvdb_id':[], 'Genome':[], 'Containment':[]}).write_parquet('uhvdb_phist.parquet')"
    """
}
