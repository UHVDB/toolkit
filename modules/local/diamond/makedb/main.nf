process DIAMOND_MAKEDB {
    tag "${meta.id}"
    label "process_super_high"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b0/b02ee5b879ab20cb43dc8a37f94cd193ff903431c91aa9fa512d697ad2ce60d0/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-218fef62763f7568_1?_gl=1*1rtwf0g*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.

    input:
    tuple val(meta) , path(fna_gz)

    output:
    tuple val(meta) , path("${meta.id}.dmnd")   , emit: dmnd
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    """
    ### Convert FNA to FAA
    pyrodigal-gv \\
        -i ${fna_gz} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        --jobs ${task.cpus} \\
        > /dev/null 2>&1

    ### Create DIAMOND database
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${meta.id}.pyrodigalgv.faa \\
        -d ${meta.id}

    ### Cleanup
    rm -rf ${meta.id}.pyrodigalgv.faa
    """
}
