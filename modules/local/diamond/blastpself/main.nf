process DIAMOND_BLASTPSELF {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b0/b02ee5b879ab20cb43dc8a37f94cd193ff903431c91aa9fa512d697ad2ce60d0/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-218fef62763f7568_1?_gl=1*1rtwf0g*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.

    input:
    tuple val(meta) , path(faa_gz)

    output:
    tuple val(meta), path("${meta.id}.diamond_blastp.tsv.gz")   , emit: tsv_gz
    path(".command.log")                                        , emit: log
    path(".command.sh")                                         , emit: script

    script:
    """
    ### Make self DB
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${faa_gz} \\
        -d ${meta.id}

    ### Align genes to self
    diamond \\
        blastp \\
        --masking none \\
        -k 1000 \\
        -e 1e-3 \\
        --faster \\
        --query ${faa_gz} \\
        --db ${meta.id}.dmnd \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.diamond_blastp.tsv

    ### Compress
    gzip ${meta.id}.diamond_blastp.tsv

    ### Cleanup
    rm -rf ${meta.id}.dmnd
    """
}
