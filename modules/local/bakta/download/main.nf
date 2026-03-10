process BAKTA_DOWNLOAD {
    tag "bakta_db"
    label 'process_long'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2dfb94caa02cda7e8fa885d1cd8190620d1a067c4a5045e84df6cfc2f89b7d12/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ab739ec5f76b6b51_1?_gl=1*2ib32a*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.
    storeDir "${params.db_dir}/bakta/1.12_${params.bakta_db_version}"
    tag "bakta v1.12_${params.bakta_db_version}"

    output:
    path("db*")             , emit: db
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    # download bakta database
    bakta_db download \\
        --type ${params.bakta_db_version}
    """
}
