process UHVDB_PROTEINHASH {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta), path(tsv_gzs)
    path(uhvdb_tsv_gz)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.prothash.tsv.gz")     , emit: tsv_gz
    tuple val(meta), path("${meta.id}.new_proteins.faa.gz") , emit: faa_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    def uhvdb_tsv_gz_input = uhvdb_tsv_gz ? "--input_uhvdb_prothash_tsv ${uhvdb_tsv_gz}" : "--input_uhvdb_prothash_tsv ''"
    """
    ### Concatenate TSVs
    for file in ${tsv_gzs}; do
        cat \${file} >> ${meta.id}.combined_prothash.tsv.gz
    done

    ### 
    # 1. Identify new hashes that are not in the existing UHVDB (if provided)
    # 2. Write out new unique sequences in fasta format
    # 3. Write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    uhvdb_protein_hash.py \\
        --input_prothash_tsv ${meta.id}.combined_prothash.tsv.gz \\
        ${uhvdb_tsv_gz_input} \\
        --output_combined_prothash_tsv ${meta.id}.prothash.tsv \\
        --output_new_unique_fna ${meta.id}.new_proteins.faa

    ### Compress
    gzip ${meta.id}.prothash.tsv ${meta.id}.new_proteins.faa

    ### Cleanup
    rm -rf ${meta.id}.combined_prothash.tsv.gz
    """
}
