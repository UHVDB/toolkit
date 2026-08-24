process SPACEREXTRACTOR_CREATETARGETDB {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/26/262593463fefcf7fcfe9bd767cd939f03bedaa0ba8cdf0846b0acd7c64f49035/data' :
        'community.wave.seqera.io/library/spacerextractor_polars_pigz:281ff9610b0f603c' }"

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
