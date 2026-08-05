process SPACEREXTRACTOR_MAPTOTARGET {
    tag "${meta2.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    // Wave freeze: community.wave.seqera.io/library/spacerextractor_polars_pigz:281ff9610b0f603c
    // (Singularity pulls the Docker image; ORAS SIF tags were Docker manifests and failed to pull)
    container 'community.wave.seqera.io/library/spacerextractor_polars_pigz:281ff9610b0f603c'

    input:
    tuple val(meta), path(fna_gz)
    path(spacer_info)
    tuple val(meta2), path(target_db)

    output:
    tuple val(meta2), path("${meta2.id}.spacerextractor.tsv.gz"), emit: se_tsv_gz
    tuple val(meta2), path("${meta2.id}.crisprhost.tsv.gz")     , emit: crisprhost_tsv_gz

    script:
    """
    ### Map to target
    spacerextractor \\
        map_to_target \\
            -i ${fna_gz} \\
            -d ${target_db} \\
            -o ${meta2.id}_map_results \\
            -t ${task.cpus}

    mv ${meta2.id}_map_results/*_vs_virus_targets_db_all_hits.tsv ${meta2.id}.spacerextractor_map.tsv

    ### Filter and get taxonomy
    uhvdb_crisprhost.py \\
        --host_info ${spacer_info} \\
        --se_tsv ${meta2.id}.spacerextractor_map.tsv \\
        --output ${meta2.id}

    ### Compress
    pigz ${meta2.id}.spacerextractor.tsv ${meta2.id}.crisprhost.tsv

    ### Cleanup
    rm -rf ${meta2.id}_map_results/ ${meta2.id}.spacerextractor_map.tsv
    """

    stub:
    """
    echo "" | pigz > ${meta2.id}.spacerextractor.tsv.gz
    echo "" | pigz > ${meta2.id}.crisprhost.tsv.gz
    """
}
