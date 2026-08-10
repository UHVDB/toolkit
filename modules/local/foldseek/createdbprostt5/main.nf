process FOLDSEEK_CREATEDBPROSTT5 {
    tag "${meta.id}"
    label 'process_gpu'

    // GPU binary via Dockerfile (Wave) or frozen ORAS image; biocontainers foldseek is CPU-only
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/fa/fa4194388365921de870bac23d8693e92bfb16ca165c0344a5d9e13cd5b2e6af/data' :
        'community.wave.seqera.io/library/foldseek:gpu' }"

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
