process EMPATHI_INSTALL {
    tag "Empathi v1.0.6"
    label 'process_single'
    storeDir "${params.dbdir}/empathi/1.0.6"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b8a045eec34dae0f3027ab806e8f218a77c5755355480688e500ef644dd5473/data' :
        'community.wave.seqera.io/library/git_git-lfs:latest' }"

    output:
    path("empathi/models/"), emit: models

    script:
    """
    ### Install git lfs
    git lfs install

    ### Clone empathi models
    git clone https://huggingface.co/AlexandreBoulay/empathi
    """

    stub:
    """
    mkdir -p empathi/models
    touch empathi/models/.stub
    """
}
