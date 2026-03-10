process PROTEINSIMILARITY_NORMSCORE {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4b/4b95a1690d027e4acd174874230bf4a822608228059af6c42db7834745a12e47/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-8060f2888f702769_1?_gl=1*7w7ki4*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(self_tsv_gz) , path(ref_tsv_gz)

    output:
    tuple val(meta) , path("${meta.id}.normscore.tsv.gz")   , emit: tsv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Calculate normalized bitscore
    norm_score.py \\
        --input ${ref_tsv_gz} \\
        --self_score ${self_tsv_gz} \\
        --min_score 5.5 \\
        --output ${meta.id}.normscore.tsv

    ### Compress
    gzip ${meta.id}.normscore.tsv
    """
}
