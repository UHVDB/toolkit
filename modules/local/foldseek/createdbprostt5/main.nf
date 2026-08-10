process FOLDSEEK_CREATEDBPROSTT5 {
    tag "${meta.id}"
    label 'process_gpu'

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/foldseek:10-gpu' :
        'docker.io/carsonjm/foldseek:10-gpu' }"

    input:
    tuple val(meta), path(faa)
    path(weights)

    output:
    tuple val(meta), path("${meta.id}_3di_db*"), emit: db

    script:
    """
    ### Convert AA to 3Di (requires CUDA-enabled foldseek + host --nv)
    foldseek createdb \\
        ${faa} \\
        ${meta.id}_3di_db \\
        --prostt5-model ${weights} \\
        --threads ${task.cpus} \\
        --gpu 1
    """

    stub:
    """
    touch ${meta.id}_3di_db
    touch ${meta.id}_3di_db.index
    """
}
