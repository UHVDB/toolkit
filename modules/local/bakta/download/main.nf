process BAKTA_DOWNLOAD {
    tag "bakta v1.12_${params.bakta_db_version}"
    label 'process_long'
    storeDir "${params.dbdir}/bakta/1.12_${params.bakta_db_version}"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2dfb94caa02cda7e8fa885d1cd8190620d1a067c4a5045e84df6cfc2f89b7d12/data' :
        'community.wave.seqera.io/library/bakta:1.11.0--pyhdfd78af_0' }"

    output:
    path("db*") , emit: db

    script:
    """
    # download bakta database
    bakta_db download \\
        --type ${params.bakta_db_version}
    """

    stub:
    """
    mkdir -p db
    touch db/.stub
    """
}
