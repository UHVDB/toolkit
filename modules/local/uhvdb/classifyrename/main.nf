process UHVDB_CLASSIFYRENAME {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta) , path(tsv_gz)
    path(map_tsv_gz)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.classify.tsv.gz")    , emit: tsv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Replace seq_name in classify.tsv.gz 
    uhvdb_classify_rename.py \\
        --classify_tsv ${tsv_gz} \\
        --id_mapping_tsv ${map_tsv_gz} \\
        --output_tsv ${meta.id}.classify.tsv
    
    ### Compress
    gzip ${meta.id}.classify.tsv
    """
}
