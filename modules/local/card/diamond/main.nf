process CARD_DIAMOND {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b7c8dc0d49f17b63_1?_gl=1*1sesm3q*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(faa_gz)  
    path(dmnd)

    output:
    tuple val(meta), path("${meta.id}.card.tsv.gz") , emit: tsv_gz
    path(".command.log")                            , emit: log
    path(".command.sh")                             , emit: script

    script:
    """
    ### Run DIAMOND
    diamond \\
        blastp \\
        --very-sensitive --iterate --max-target-seqs 1 --id 80 --query-cover 40 --subject-cover 40 \\
        --query ${faa_gz} \\
        --db ${dmnd} \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.card.tsv

    ### Compress
    gzip ${meta.id}.card.tsv
    """
}
