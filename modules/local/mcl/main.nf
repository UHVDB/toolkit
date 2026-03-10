process MCL {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://depot.galaxyproject.org/singularity/mcl%3A22.282--pl5321h7b50bb2_4"

    input:
    tuple val(meta), path(tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.mcl.gz")      , emit: mcl_gz
    tuple val(meta), path("${meta.id}.gani.tsv.gz") , emit: tsv_gz
    path(".command.log")                            , emit: log
    path(".command.sh")                             , emit: script

    script:
    """
    ### Decompress
    gunzip -c ${tsv_gz} > ${meta.id}.gani.tsv

    ### Run MCL
    mcl \\
        ${meta.id}.gani.tsv \\
        --abc \\
        -sort revsize \\
        -te ${task.cpus} \\
        -o ${meta.id}.mcl

    ### Compress
    gzip ${meta.id}.mcl ${meta.id}.gani.tsv
    """
}
