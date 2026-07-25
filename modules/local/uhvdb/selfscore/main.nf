process UHVDB_SELFSCORE {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c5/c54a858d4e1e2b37fa25fdef57ef3d42549df7822135f66b86b3ca66a97936de/data':
        'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071' }"
    
    input:
    tuple val(meta), path(tsv_gz)

    output:
    tuple val(meta), path("*.selfscore.tsv.gz"), emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Calculate self score
    uhvdb_selfscore.py \\
        --input ${tsv_gz} \\
        --output ${prefix}.selfscore.tsv

    ### Compress
    gzip ${prefix}.selfscore.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.selfscore.tsv.gz
    """
}
