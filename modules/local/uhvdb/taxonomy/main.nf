process UHVDB_TAXONOMY {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/30/3056eb370847d66f9690e620637cc60f0960b5c006aacf0e72651efb90e570ea/data':
        'community.wave.seqera.io/library/fastexcel_polars:14bb0a75e935c888' }"

    input:
    tuple val(meta), path(normscore_tsv_gz)
    tuple val(meta2), path(classify_tsv_gz)
    tuple val(meta3), path(vmr_url)

    output:
    tuple val(meta), path("${meta.id}.tsv.gz")  , emit: tsv_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Combine taxonomy data
    uhvdb_taxonomy.py \\
        --normscore_tsv ${normscore_tsv_gz} \\
        --classify_tsv ${classify_tsv_gz} \\
        --vmr_url ${vmr_url} \\
        --output ${meta.id}.tsv

    ### Compress
    gzip ${meta.id}.tsv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.tsv.gz
    """
}
