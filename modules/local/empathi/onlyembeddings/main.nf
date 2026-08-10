process EMPATHI_ONLYEMBEDDINGS {
    tag "${meta.id}"
    label 'process_gpu'

    // Wave builds Dockerfile (empathi + CUDA pytorch). Sylabs/CPU images are not reliable for GPU.
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' :
        'pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' }"

    input:
    tuple val(meta), path(faa_gz)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.embeddings.csv.gz"), emit: csv_gz

    script:
    """
    ### Setup
    gunzip -c ${faa_gz} > ${meta.id}.faa

    ### Run EMPATHI embeddings (GPU)
    empathi \\
        ${meta.id}.faa \\
        ${meta.id} \\
        --models_folder ${models} \\
        --only_embeddings \\
        --threads ${task.cpus} \\
        --output_folder ./ \\
        --confidence 0.5

    ### Compress
    mv *.csv ${meta.id}.embeddings.csv
    gzip ${meta.id}.embeddings.csv

    ### Cleanup
    rm -rf ${meta.id}.faa
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.embeddings.csv.gz
    """
}
