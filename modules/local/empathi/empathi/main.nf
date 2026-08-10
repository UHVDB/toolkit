process EMPATHI_EMPATHI {
    tag "${meta.id}"
    label 'process_medium'

    // Same image as embeddings for ABI consistency (prediction is CPU-light)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' :
        'pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' }"

    input:
    tuple val(meta), path(csv_gz)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.empathi.csv.gz"), emit: csv_gz

    script:
    """
    ### Decompress
    gunzip -f -c ${csv_gz} > ${csv_gz.getBaseName()}

    ### Run empathi predictions
    empathi \\
        ${csv_gz.getBaseName()} \\
        results \\
        --models_folder ${models} \\
        --threads ${task.cpus} \\
        --output_folder ./ \\
        --confidence 0.5

    ### Compress
    mv results/predictions_results.csv ${meta.id}.empathi.csv
    gzip ${meta.id}.empathi.csv

    ### Cleanup
    rm -rf results/ ${csv_gz.getBaseName()}
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.empathi.csv.gz
    """
}
