process SPACEREXTRACTOR_MAPTOTARGET {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4a/4a81646a707cbd07603fcec71562b5c0f1d36e0fb01fe2e8ef7c11ad85de3a4d/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-57a9434a25e32f73_1?_gl=1*uwzavr*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(fna_gz)
    tuple val(meta2), path(target_db)

    output:
    tuple val(meta), path("${meta2.id}.spacerextractor.tsv.gz") , emit: se_tsv_gz
    tuple val(meta), path("${meta2.id}.crisprhost.tsv.gz")      , emit: crisprhost_tsv_gz
    path(".command.log")                                        , emit: log
    path(".command.sh")                                         , emit: script

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
        --host_info ${projectDir}/assets/zenodo/gtdb/GTDB_Host_Info.tsv.gz \\
        --se_tsv ${meta2.id}.spacerextractor_map.tsv \\
        --output ${meta2.id}

    ### Compress
    gzip ${meta2.id}.spacerextractor.tsv ${meta2.id}.crisprhost.tsv
    
    ### Cleanup
    rm -rf ${meta2.id}_map_results/ ${meta2.id}.spacerextractor_map.tsv
    """
}
