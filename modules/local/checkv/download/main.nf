process CHECKV_DOWNLOAD {
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ed/eda5d14cc74e9df5c23ea0fa0d5126d63438792c770b3485a6dfeaa4e6171778/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-fb2c59f3624cccf3_1?_gl=1*io0i31*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    storeDir "${params.db_dir}/checkv/1.0.3"
    tag "CheckV v1.0.3; db v1.5"

    output:
    path "checkv_db/*"  , emit: checkv_db
    path ".command.log" , emit: log
    path ".command.sh"  , emit: script

    script:
    """
    ### Download database
    checkv download_database \\
        ./checkv_db/
    """
}
