process TRTRIMMER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/04/04234935a0dd1d913e1b4da7cd6f57a5ecdc9f6b28640621c3eaf1d5b1b668eb/data' :
        'community.wave.seqera.io/library/tr-trimmer:0.5.0--9b3177460ba5806c' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.tr-trimmer.fna.gz")    , emit: fna_gz
    tuple val("${task.process}"), val('tr-trimmer'), eval('tr-trimmer --version'), topic: versions, emit: versions_tr_trimmer

    script:
    def prefix = task.ext.prefix ?: "${meta.id}.tr-trimmer"
    """
    ### Trim DTRs
    tr-trimmer \\
        ${fasta} \\
        --min-length 20 \\
        --include-tr-info \\
        > ${prefix}.fna

    ### Compress
    gzip ${prefix}.fna
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.tr-trimmer"
    """
    echo "" | gzip > ${prefix}.fna.gz
    """
}
