process IPHOP_PREDICT {
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/35/35c0c5c907f5b67fb4ccd64d10d843724d4c9dbbf6470ea018a692989f536804/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-163f2f3752036bc0_1?_gl=1*c1jy3r*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    tag "${meta.id}"

    input:
    tuple val(meta), path(fna_gz)
    path(iphop_db)

    output:
    tuple val(meta), path("${meta.id}.iphop_genus.csv.gz")  , emit: genus_csv_gz
    tuple val(meta), path("${meta.id}.iphop_genome.csv.gz") , emit: genome_csv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Decompress
    gunzip -c ${fna_gz} > ${meta.id}.fna

    ### Run iphop
    iphop \\
        predict \\
        --fa_file ${meta.id}.fna \\
        --db_dir ${iphop_db} \\
        --out_dir ${meta.id}.iphop_out \\
        --num_threads ${task.cpus} \\
        --min_score 75 \\
        --max_thread_wish 4

    ### Compress
    gzip -c ${meta.id}.iphop_out/Host_prediction_to_genus_m75.csv > ${meta.id}.iphop_genus.csv.gz
    gzip -c ${meta.id}.iphop_out/Host_prediction_to_genome_m75.csv > ${meta.id}.iphop_genome.csv.gz

    ### Cleanup
    rm -rf ${iphop_db}/Wdir ${meta.id}.fna ${meta.id}.iphop_out
    """
}
