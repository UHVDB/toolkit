process FOLDSEEK_CREATEDBPROSTT5 {
    tag "${meta.id}"
    label "process_gpu"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa4194388365921de870bac23d8693e92bfb16ca165c0344a5d9e13cd5b2e6af/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-12803fde2c4845e0_1?_gl=1*9efwsl*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(faa)
    path(weights)

    output:
    tuple val(meta), path("${meta.id}_3di_db*") , emit: db
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    """
    ### Convert AA to 3Di
    foldseek createdb \\
        ${faa} \\
        ${meta.id}_3di_db \\
        --prostt5-model ${weights} \\
        --threads ${task.cpus} \\
        --gpu 1
    """
}
