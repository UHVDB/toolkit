process FOLDSEEK_CREATEDB {
    tag "foldseek_db"
    label 'process_high'
    storeDir "${params.dbdir}/foldseek"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa4194388365921de870bac23d8693e92bfb16ca165c0344a5d9e13cd5b2e6af/data' :
        'quay.io/biocontainers/foldseek:10.941cd33--h4ac6f70_0' }"

    input:
    path(tar_gz)

    output:
    path("viral_ref_db*"), emit: db
    path("weights")      , emit: weights

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

    stub:
    """
    touch viral_ref_db
    touch viral_ref_db.index
    mkdir -p weights
    touch weights/.stub
    """
}
