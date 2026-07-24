process SPRING_COVERM {
    tag "${meta.id}"
    label "process_medium"

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5d/5de335efc8d9c77033e95938340bd6de945e04cee350f72cca3a8ef6a3eb3313/data'
        : 'community.wave.seqera.io/library/coverm_spring:c5d204e8ad6f34c0'}"

    input:
    tuple val(meta), path(spring), path(fna_gz)

    output:
    tuple val(meta), path('*.depth.tsv.gz'), emit: tsv_gz
    tuple val(meta), path('*.bam')         , emit: bam, optional: true
    tuple val("${task.process}"), val('coverm'), eval('coverm --version | sed "s/coverm //"'), emit: versions_coverm, topic: versions
    tuple val("${task.process}"), val('spring'), val('1.1.1'), topic: versions, emit: versions_spring
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix         = task.ext.prefix ?: "${meta.id}"
    def spring_out     = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    def coverm_reads   = meta.single_end ? "--single ${meta.id}.fastq.gz" : "--coupled ${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    """
    ### decompress spring
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped-fastq \\
        --num-threads ${task.cpus}

    TMPDIR=.

    coverm contig \\
        --threads ${task.cpus} \\
        ${coverm_reads} \\
        --reference ${fna_gz} \\
        --bam-file-cache-directory _bam_cache/ \\
        --mapper strobealign \\
        --methods trimmed_mean mean variance covered_bases length \\
        --output-file ${prefix}.depth.tsv

    gzip ${prefix}.depth.tsv
    mv _bam_cache/*.bam . || true
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.depth.tsv.gz
    touch ${prefix}.bam
    """
}
