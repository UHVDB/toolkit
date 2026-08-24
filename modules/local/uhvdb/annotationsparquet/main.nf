process UHVDB_ANNOTATIONS_PARQUET {
    label 'process_high'
    tag "UHVDB 5.${params.uhvdb_version}"
    storeDir "${params.dbdir}/uhvdb/${params.uhvdb_version}"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b8/b80c0153f3740c99d626acdb271cc7c62e220ff17d8f8421493aa6365c08038e/data':
        'community.wave.seqera.io/library/pysam_numpy_polars:ffb596c8bdfe2ed8' }"

    input:
    path(annotations_tsv_gz)

    output:
    path("uhvdb_protein_annotations.parquet"), emit: protein_annotations_parquet

    script:
    """
    python -c 'import polars as pl; pl.scan_csv("${annotations_tsv_gz}", separator="\\t").sink_parquet("uhvdb_protein_annotations.parquet", compression="zstd")'
    """

    stub:
    """
    python -c "import polars as pl; pl.DataFrame({'protein_id':[], 'genomovar_rep':[], 'start':[], 'end':[]}).write_parquet('uhvdb_protein_annotations.parquet')"
    """
}
