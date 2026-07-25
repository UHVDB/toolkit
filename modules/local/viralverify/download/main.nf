process VIRALVERIFY_DOWNLOAD {
    label 'process_single'
    tag "viralverify 1.1"
    storeDir "${params.dbdir}/viralverify/1.1"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/3b/3b54fa9135194c72a18d00db6b399c03248103f87e43ca75e4b50d61179994b3/data'
        : 'community.wave.seqera.io/library/wget:1.21.4--8b0fcde81c17be5e'}"

    output:
    path "nbc_hmms.hmm", emit: viralverify_db

    script:
    """
    ### Download database
    wget -O nbc_hmms.hmm.gz https://ndownloader.figshare.com/files/17904323

    ### Decompress
    gunzip nbc_hmms.hmm.gz
    """

    stub:
    """
    ### Touch empty database file
    touch nbc_hmms.hmm
    """
}