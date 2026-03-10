process TRTRIMMER {
    tag "${meta.id}"
    label 'process_super_high'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.tr-trimmer.fna.gz")   , emit: fna_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Trim DTRs
    tr-trimmer \\
        ${fasta} \\
        --min-length 20 --include-tr-info \\
        > ${meta.id}.tr-trimmer.fna

    ### Compress
    gzip ${meta.id}.tr-trimmer.fna
    """
}
