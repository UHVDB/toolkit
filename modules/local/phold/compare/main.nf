process PHOLD_COMPARE {
    tag "${meta.id}"
    label "process_super_high"
    container null
    conda "${moduleDir}/environment.yml"

    input:
    tuple val(meta) , path(faa_gz), path(predict)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.phold.tsv.gz")    , emit: tsv_gz
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    """
    ### Decompress
    gunzip -f -c ${faa_gz} > ${meta.id}.faa

    ### Run phold
    phold proteins-compare \\
        --input ${meta.id}.faa \\
        --predictions_dir ${predict} \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold

    ### Compress
    mv ${meta.id}_phold/phold_per_cds_predictions.tsv ${meta.id}.phold.tsv

    gzip ${meta.id}.phold.tsv

    ### Cleanup
    rm -rf ${meta.id}_phold/logs ${meta.id}_phold/sub_db_tophits \\
        ${meta.id}_phold/phold_3di.fasta ${meta.id}_phold/phold_aa.fasta \\
        ${meta.id}_phold/phold_all_cds_functions.tsv \\
        ${meta.id}_phold/phold_run*.log ${meta.id}_phold \\
        ${meta.id}.faa
    """
}
