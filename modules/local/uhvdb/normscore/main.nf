process UHVDB_NORMSCORE {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c5/c54a858d4e1e2b37fa25fdef57ef3d42549df7822135f66b86b3ca66a97936de/data':
        'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071' }"
    
    input:
    tuple val(meta), path(ref_tsv_gz), path(self_tsv_gz)

    output:
    tuple val(meta), path("*.normscore.tsv.gz"), emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Calculate normalized score
    uhvdb_normscore.py \\
        --input ${ref_tsv_gz} \\
        --self_score ${self_tsv_gz} \\
        --min_score 5.5 \\
        --output ${prefix}.normscore.tsv

    ### Compress
    gzip ${prefix}.normscore.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.normscore.tsv.gz
    """
}
