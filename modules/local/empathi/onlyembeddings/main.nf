process EMPATHI_ONLYEMBEDDINGS {
    tag "${meta.id}"
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(faa_gz)
    path(models)

    output:
    tuple val(meta), path("${meta.id}.embeddings.csv.gz")   , emit: csv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Setup
    export HF_HOME=${params.db_dir}/.huggingface-cache
    gunzip -c ${faa_gz} > ${meta.id}.faa

    ### Run EMPATHI
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
    """
}
