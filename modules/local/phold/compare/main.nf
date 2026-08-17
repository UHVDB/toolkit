process PHOLD_COMPARE {
    tag "${meta.id}"
    label 'process_gpu'

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/phold:1.2.2-cuda12.1' :
        'docker.io/carsonjm/phold:1.2.2-cuda12.1' }"

    input:
    tuple val(meta), path(faa_gz), path(predict)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.phold.tsv.gz"), emit: tsv_gz

    script:
    """
    ### Image has phold but no foldseek binary; compare --foldseek_gpu needs it.
    wget -q https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz
    tar -xzf foldseek-linux-gpu.tar.gz
    export PATH="\$PWD/foldseek/bin:\$PATH"
    command -v foldseek

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
        ${meta.id}.faa foldseek foldseek-linux-gpu.tar.gz
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.phold.tsv.gz
    """
}
