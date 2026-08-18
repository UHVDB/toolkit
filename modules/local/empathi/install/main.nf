process EMPATHI_INSTALL {
    tag "Empathi v1.0.6"
    label 'process_single'
    storeDir "${params.dbdir}/empathi/1.0.6"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/empathi:1.0.6-cuda12.1' :
        'docker.io/carsonjm/empathi:1.0.6-cuda12.1' }"

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
