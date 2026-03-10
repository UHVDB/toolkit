process PHOLD_PREDICT {
    tag "${meta.id}"
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(faa_gz)
    path(db)

    output:
    tuple val(meta), path("${meta.id}_phold_predict")   , emit: predict
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    """
    ### Decompress
    gunzip -c ${faa_gz} > ${meta.id}.faa

    ### Run phold predict
    phold proteins-predict \\
        --input ${meta.id}.faa \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold_predict
    
    ### Cleanup
    rm -rf ${meta.id}.faa
    """
}
