process UHVDB_SYLPHTAX {
    tag "UHVDB sylphtax"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f6/f6f9d332e4b15ffa29e886f0224de4ed068d4ebff7e8dd3287c9c2b8521617a1/data' :
        'community.wave.seqera.io/library/taxopy_polars:ece13f10ab3ee41a' }"

    input:
    path(metadata_tsv_gz)

    output:
    path("uhvdb_metadata_sylphtax.tsv.gz"), emit: tsv_gz

    script:
    """
    uhvdb_build_sylphtax.py \\
        --metadata-tsv ${metadata_tsv_gz} \\
        --output uhvdb_metadata_sylphtax.tsv.gz
    """

    stub:
    """
    python -c "import gzip; gzip.open('uhvdb_metadata_sylphtax.tsv.gz', 'wt').write('')"
    """
}
