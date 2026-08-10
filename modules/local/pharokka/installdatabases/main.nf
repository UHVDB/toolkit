process PHAROKKA_INSTALLDATABASES {
    tag "Pharokka v1.8.2"
    label 'process_single'
    storeDir "${params.dbdir}/pharokka/1.8.2"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e8fd5a881f4f4dd544da48510ca945aa398342fd1439548cea09176d4b47c25/data' :
        'quay.io/biocontainers/pharokka:1.7.5--pyhdfd78af_0' }"

    output:
    path("pharokka_db/"), emit: db

    script:
    """
    ### Download DB
    install_databases.py \\
        -o pharokka_db
    """

    stub:
    """
    mkdir -p pharokka_db
    touch pharokka_db/.stub
    """
}
