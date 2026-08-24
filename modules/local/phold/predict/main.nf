process PHOLD_PREDICT {
    tag "${meta.id}"
    label 'process_gpu'

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/phold:1.2.2-cuda12.1' :
        'docker.io/carsonjm/phold:1.2.2-cuda12.1' }"

    input:
    tuple val(meta), path(faa_gz)
    path(db)

    output:
    tuple val(meta), path("${meta.id}_phold_predict"), emit: predict

    script:
    """
    ### Decompress
    gunzip -c ${faa_gz} > ${meta.id}.faa

    ### Run phold predict (ProstT5 on GPU)
    phold proteins-predict \\
        --input ${meta.id}.faa \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold_predict

    ### Cleanup
    rm -rf ${meta.id}.faa
    """

    stub:
    """
    mkdir -p ${meta.id}_phold_predict
    touch ${meta.id}_phold_predict/.stub
    """
}
