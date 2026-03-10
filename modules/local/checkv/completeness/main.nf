process CHECKV_COMPLETENESS {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/eb/ebf6fd744e8dbc26020bc6d5edaae5588703444bdf1fc6788f6dc6320709fa06/data"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path("${meta.id}_completeness.tsv.gz")     , emit: tsv_gz
    path ".command.log"                                         , emit: log
    path ".command.sh"                                          , emit: script

    script:
    """
    checkv \\
        completeness \\
        -t ${task.cpus} \\
        -d ${db} \\
        ${fasta} \\
        ${meta.id}

    gzip -c ${meta.id}/completeness.tsv > ${meta.id}_completeness.tsv.gz
    """
}
