process SEQKIT_GREP {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/85/85b40b925e4d4a62f9b833bbb0646d7ea6cf53d8a875e3055f90da757d7ccd27/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ec0d76090cceee7c_1?_gl=1*d6zgjg*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(tsv_gz), path(fna_gz)
    val(invert_match)

    output:
    tuple val(meta), path("${meta.id}.grep.fna.gz") , emit: fna_gz, optional: true
    path(".command.log")                            , emit: log
    path(".command.sh")                             , emit: script

    script:
    def invert_flag = invert_match ? '--invert-match' : ''
    """
    ### Extract first column of gzipped tsv to get patterns
    zcat ${tsv_gz} | cut -f1 > ${meta.id}.patterns.txt

    ### Split sequences
    seqkit \\
        grep \\
            ${fna_gz} \\
            ${invert_flag} \\
            --threads ${task.cpus} \\
            --pattern-file ${meta.id}.patterns.txt \\
            --out-file ${meta.id}.grep.fna.gz

    ### Cleanup
    rm ${meta.id}.patterns.txt
    """
}
