process UHVDB_UNIQUEHASH {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta), path(new_seqhasher_tsv_gzs)
    path(uhvdb_seqhasher_tsv_gz)
    path(new_classify_tsv_gz)
    path(uhvdb_metadata_tsv_gz)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.seqhasher.tsv.gz")        , emit: tsv_gz
    tuple val(meta), path("${meta.id}.new_seqhasher.fna.gz")    , emit: fna_gz
    path ".command.log"                                         , emit: log
    path ".command.sh"                                          , emit: script

    script:
    def uhvdb_seqhasher_tsv_gz_input = uhvdb_seqhasher_tsv_gz ? "--input_uhvdb_seqhash_tsv ${uhvdb_seqhasher_tsv_gz}" : "--input_uhvdb_seqhash_tsv ''"
    def uhvdb_metadata_tsv_gz_input = uhvdb_metadata_tsv_gz ? "--uhvdb_metadata_tsv_gz ${uhvdb_metadata_tsv_gz}" : "--uhvdb_metadata_tsv_gz ''"
    """
    ### Concatenate TSVs
    for file in ${tsv_gzs}; do
        cat \${file} >> ${meta.id}.combined_seqhasher.tsv.gz
    done

    ### 
    # 1. Identify new hashes that are not in the existing UHVDB (if provided)
    # 2. Write out new unique sequences in fasta format
    # 3. Write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    uhvdb_unique_hash.py \\
        --input_seqhash_tsv ${meta.id}.combined_seqhasher.tsv.gz \\
        ${uhvdb_tsv_gz_input} \\
        ${uhvdb_metadata_tsv_gz_input} \\
        --new_classify_tsv_gz ${new_classify_tsv_gz} \\
        --output_combined_seqhash_tsv ${meta.id}.seqhasher.tsv \\
        --output_new_unique_fna ${meta.id}.new_seqhasher.fna

    ### Compress
    gzip ${meta.id}.seqhasher.tsv ${meta.id}.new_seqhasher.fna

    ### Cleanup
    rm -rf ${meta.id}.combined_seqhasher.tsv.gz
    """
}
