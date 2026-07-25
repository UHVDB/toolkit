process FIND_CONCATENATE_TRTRIMMER_SEQHASHER {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/83/8364f10dc30182013a6d389a8439e404beada81c931fdfc9d646fab526d7262e/data'
        : 'community.wave.seqera.io/library/tr-trimmer_seq-hasher_pigz_findutils_coreutils:71209e8a9f23e333'}"

    input:
    tuple val(meta), path(fna_gz, stageAs: 'to_concatenate/*', arity: '1..*')

    output:
    tuple val(meta), path("*.tsv.gz")    , emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # concatenate fasta files
    while IFS= read -r -d \$'\\0' file; do
            pigz -cd -p ${task.cpus} \$file \\
                >> ${meta.id}.fna
        done < <( find to_concatenate/ -mindepth 1 -print0 | sort -z )

    # trim DTRs
    tr-trimmer \\
        ${meta.id}.fna \\
        --min-length 20 \\
        --include-tr-info \\
        > ${prefix}.trtrimmer.fna

    # calculate sequence hashes
    seq-hasher \\
        ${prefix}.trtrimmer.fna \\
        --multi-kmer-hashing \\
        --circular-kmers \\
        --print-sequence \\
        > ${prefix}.seqhasher.tsv

    # compress output
    pigz ${prefix}.seqhasher.tsv

    # cleanup
    rm -rf ${prefix}.trtrimmer.fna ${meta.id}.fna
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.seqhasher.tsv.gz
    """
}
