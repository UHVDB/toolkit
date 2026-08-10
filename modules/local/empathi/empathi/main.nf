process EMPATHI_EMPATHI {
    tag "${meta.id}"
    label 'process_medium'

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/empathi:1.0.6-cuda12.1' :
        'docker.io/carsonjm/empathi:1.0.6-cuda12.1' }"

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
