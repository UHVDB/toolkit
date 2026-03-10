process EMPATHI_EMPATHI {
    tag "${meta.id}"
    label "process_medium"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(csv_gz)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.empathi.csv.gz")  , emit: csv_gz
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    """
    ### Decompress
    gunzip -f -c ${csv_gz} > ${csv_gz.getBaseName()}

    ### Run empathi
    empathi \\
        ${csv_gz.getBaseName()} \\
        results \\
        --models_folder ${models} \\
        --only_embeddings \\
        --threads ${task.cpus} \\
        --output_folder ./ \\
        --confidence 0.5

    ### Compress
    mv results/predictions_results.csv ${meta.id}.empathi.csv
    gzip ${meta.id}.empathi.csv

    ### Cleanup
    rm -rf results/ ${csv_gz.getBaseName()}
    """
}
