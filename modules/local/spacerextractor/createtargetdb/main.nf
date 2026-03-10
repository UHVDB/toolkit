process SPACEREXTRACTOR_CREATETARGETDB {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/29/2900c330cd8dd25094b4cd86e4a32a576ddb340f412ac17f6715ac4136cf495c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-f4b63d63859b49f0_1?_gl=1*1gn5au*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(fna_gz)

    output:
    tuple val(meta) , path("virus_targets_db/") , emit: db
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    """
    ### Decompress
    gunzip -c ${fna_gz} > hq_hc_virus.fna

    ### Create DB
    spacerextractor \\
        create_target_db \\
            -i hq_hc_virus.fna \\
            -d virus_targets_db \\
            -t ${task.cpus} \\
            --replace_spaces

    ### Cleanup
    rm hq_hc_virus.fna
    """
}
