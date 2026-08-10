process PHOLD_COMPARE {
    tag "${meta.id}"
    label 'process_gpu'

    // Same CUDA image as predict for ABI consistency; compare uses --foldseek_gpu when available
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' :
        'pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime' }"

    input:
    tuple val(meta), path(faa_gz), path(predict)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.phold.tsv.gz"), emit: tsv_gz

    script:
    """
    ### Decompress
    gunzip -f -c ${faa_gz} > ${meta.id}.faa

    ### Run phold compare
    phold proteins-compare \\
        --input ${meta.id}.faa \\
        --predictions_dir ${predict} \\
        --threads ${task.cpus} \\
        --database ${db} \\
        --output ${meta.id}_phold \\
        --foldseek_gpu

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

    stub:
    """
    echo "" | gzip > ${meta.id}.phold.tsv.gz
    """
}
