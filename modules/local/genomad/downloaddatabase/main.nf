process GENOMAD_DOWNLOADDATABASE {
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/dc/dce9fcea87c93a5f667db6f56c102d21def6ba27d1370edb326f348f8b1a36fc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-2af08b3c6c2a1dc3_1?_gl=1*d9pf3r*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${params.db_dir}/genomad/1.9"
    tag "geNomad v1.9; db v1.11"

    output:
    path "genomad_db/"      , emit: genomad_db
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    ### Download genomad's database
    genomad \\
        download-database .
    """
}
