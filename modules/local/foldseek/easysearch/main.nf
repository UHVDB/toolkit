process FOLDSEEK_EASYSEARCH {
    tag "${meta.id}"
    label "process_high"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c4/c4ee60c498ab9dae0e2c8e492ae0e11cac0aa168943584b92efd03082e31b2bb/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-2fc3bb80bea398e1_1?_gl=1*8zrcfw*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(query_db), path(faa_gz)
    path(ref_db)

    output:
    tuple val(meta), path("${meta.id}_nohit_v_refDB.tsv.gz")    , emit: tsv_gz
    tuple val(meta), path("${meta.id}_nohit_proteins.faa.gz")   , emit: faa_gz
    path(".command.log")                                        , emit: log
    path(".command.sh")                                         , emit: script

    script:
    """
    ### Run foldseek
    foldseek easy-search \\
        ${meta.id}_3di_db \\
        viral_ref_db \\
        ${meta.id}_nohit_v_refDB.tsv \\
        tmp \\
        --threads ${task.cpus} \\
        -e 1e-3 \\
        -s 9.5 \\
        -c 0.9 \\
        --max-seqs 1

    ### Extract no hit proteins
    cut -f1 ${meta.id}_nohit_v_refDB.tsv | sort -u > ${meta.id}_nohit_proteins.txt

    seqkit grep \\
        ${faa_gz} \\
        --pattern-file ${meta.id}_nohit_proteins.txt \\
        --invert-match \\
        --out-file ${meta.id}_nohit_proteins.faa.gz

    ### Compress
    gzip ${meta.id}_nohit_v_refDB.tsv

    ### Cleanup
    rm -rf tmp ${meta.id}_nohit_proteins.txt ${meta.id}_3di_db
    """
}
