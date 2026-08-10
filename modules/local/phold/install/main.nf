process PHOLD_INSTALL {
    tag "Phold v1.2.2"
    label 'process_gpu'
    storeDir "${params.dbdir}/phold/1.2.2"

    // Wave builds Dockerfile (phold + CUDA pytorch). Biocontainers phold is CPU-only.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' :
        'pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' }"

    output:
    path("phold_db/"), emit: db

    script:
    """
    # download phold database with FoldSeek-GPU layout
    phold install \\
        -d phold_db \\
        -t ${task.cpus} \\
        --foldseek_gpu
    """

    stub:
    """
    mkdir -p phold_db
    touch phold_db/.stub
    """
}
