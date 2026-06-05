process CHECKV_COMPLETENESS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/checkv:1.0.3--pyhdfd78af_0':
        'quay.io/biocontainers/checkv:1.0.3--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path ("*_completeness.tsv.gz")    , emit: tsv_gz
    tuple val("${task.process}"), val("checkv"), eval("checkv -h 2>&1 | sed '1!d;s/^.*CheckV v//;s/:.*//'"), topic: versions, emit: versions_checkv

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    checkv \\
        completeness \\
        ${args} \\
        -t ${task.cpus} \\
        -d ${db} \\
        ${fasta} \\
        ${prefix}

    gzip -c ${prefix}/completeness.tsv > ${prefix}_completeness.tsv.gz
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo "" | gzip > ${prefix}_completeness.tsv.gz
    """
}
