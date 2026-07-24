process TRTRIMMER_SEQHASHER {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/6e/6ec4b60ce51bc1356c4c15e864cace6dfff1b1836d6087e96aa85fbee58f2dbe/data'
        : 'community.wave.seqera.io/library/seq-hasher_tr-trimmer:5242bb1dce65b321'}"

    input:
    tuple val(meta), path(fna_gz)

    output:
    tuple val(meta), path("*.tsv.gz")    , emit: tsv_gz
    tuple val("${task.process}"), val('seq-hasher'), eval('seq-hasher --version'), topic: versions, emit: versions_seq_hasher
    tuple val("${task.process}"), val('tr-trimmer'), eval('tr-trimmer --version'), topic: versions, emit: versions_tr_trimmer

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Trim DTRs
    tr-trimmer \\
        ${fna_gz} \\
        --min-length 20 \\
        --include-tr-info \\
        > ${prefix}.trtrimmer.fna

    ### Calculate sequence hashes
    seq-hasher \\
        ${prefix}.trtrimmer.fna \\
        --multi-kmer-hashing \\
        --circular-kmers \\
        --print-sequence \\
        > ${prefix}.seqhasher.tsv

    ### Compress output
    gzip ${prefix}.seqhasher.tsv

    ### Cleanup
    rm -rf ${prefix}.trtrimmer.fna
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.seqhasher.tsv.gz
    """
}
