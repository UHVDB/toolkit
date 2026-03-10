process SEQKIT_SEQSPLIT2 {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/85/85b40b925e4d4a62f9b833bbb0646d7ea6cf53d8a875e3055f90da757d7ccd27/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ec0d76090cceee7c_1?_gl=1*d6zgjg*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(fasta)
    val(chunk_size)

    output:
    tuple val(meta), path("split_fastas/*")     , emit: fastas_gz, optional: true
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    """
    ### Remove short contigs
    seqkit \\
        seq \\
        --threads ${task.cpus} \\
        --min-len 2000 \\
        ${fasta} \\
        --out-file ${meta.id}.fasta.gz

    ### Split sequences
    seqkit \\
        split2 \\
            ${meta.id}.fasta.gz \\
            --threads ${task.cpus} \\
            --by-size ${chunk_size} \\
            --out-dir split_fastas \\
            --extension '.gz'

    ### Cleanup
    rm ${meta.id}.fasta.gz
    """
}
