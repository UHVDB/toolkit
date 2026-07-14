process UHVDB_PRUNE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c5/c54a858d4e1e2b37fa25fdef57ef3d42549df7822135f66b86b3ca66a97936de/data':
        'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071' }"

    input:
    tuple val(meta) , path(tsv_gz), path(mcl_gz)
    val(similarity_threshold)

    output:
    tuple val(meta) , path("*.pruned.tsv.gz")  , emit: tsv_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('uhvdb_prune'), eval('uhvdb_prune.py --version'), topic: versions, emit: versions_uhvdb_prune

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Prune graph
    uhvdb_prune.py \\
        --graph ${tsv_gz} \\
        --clusters ${mcl_gz} \\
        --threshold ${similarity_threshold} \\
        --output ${prefix}.pruned.tsv

    ### Compress
    gzip -f ${prefix}.pruned.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.pruned.tsv.gz
    """
}
