process FOLDSEEK_CREATEDB {
    tag "foldseek_db"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa4194388365921de870bac23d8693e92bfb16ca165c0344a5d9e13cd5b2e6af/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-12803fde2c4845e0_1?_gl=1*9efwsl*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    storeDir "${params.db_dir}/foldseek"

    input:
    path(tar_gz)

    output:
    path("viral_ref_db*")   , emit: db
    path("weights")         , emit: weights
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    ### Create foldseek db
    foldseek createdb \\
        ${tar_gz} \\
        viral_ref_db \\
        --threads ${task.cpus}

    ### Download weights
    foldseek databases ProstT5 weights tmp

    ### Cleanup
    rm -rf *.tar.gz
    rm -rf tmp
    """
}
