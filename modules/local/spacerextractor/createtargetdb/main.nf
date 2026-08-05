process SPACEREXTRACTOR_CREATETARGETDB {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    // Wave freeze: community.wave.seqera.io/library/spacerextractor_pigz:2b6e0761a8b2d864
    // (Singularity pulls the Docker image; ORAS SIF tags were Docker manifests and failed to pull)
    container 'community.wave.seqera.io/library/spacerextractor_pigz:2b6e0761a8b2d864'

    input:
    tuple val(meta), path(fna_gz)

    output:
    tuple val(meta), path("virus_targets_db/"), emit: db

    script:
    """
    ### Decompress
    pigz -dc ${fna_gz} > hq_hc_virus.fna

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

    stub:
    """
    mkdir -p virus_targets_db
    touch virus_targets_db/stub
    """
}
