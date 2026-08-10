process EMPATHI_ONLYEMBEDDINGS {
    tag "${meta.id}"
    label 'process_gpu'

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/empathi:1.0.6-cuda12.1' :
        'docker.io/carsonjm/empathi:1.0.6-cuda12.1' }"

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
