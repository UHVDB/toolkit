process IPHOP_DOWNLOAD {
    label 'process_long'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/35/35c0c5c907f5b67fb4ccd64d10d843724d4c9dbbf6470ea018a692989f536804/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-163f2f3752036bc0_1?_gl=1*c1jy3r*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.db_dir}/iphop/${params.iphop_db_version}"
    tag "iPHoP v1.4.2; db v${params.iphop_db_version}"

    output:
    path "iphop_db"         , emit: iphop_db
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    ### Download iphop's database
    mkdir -p iphop_db_tmp/ iphop_db/
    
    iphop \\
        download \\
        --db_dir iphop_db_tmp/ \\
        --db_version ${params.iphop_db_version} \\
        --split \\
        --no_prompt

    mv iphop_db_tmp/* iphop_db/
    rm -rf iphop_db_tmp/
    """
}
