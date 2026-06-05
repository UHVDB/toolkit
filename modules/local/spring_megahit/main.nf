process SPRING_MEGAHIT {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2f/2f2fcf51423d1c494c3380acfed7d823b5f40a5397085b92757c398ae31571bf/data' :
        'community.wave.seqera.io/library/megahit_spring:6d204c382c539e7e' }"

    input:
    tuple val(meta), path(spring)

    output:
    tuple val(meta), path("*.contigs.fna.gz")  , emit: fna_gz
    tuple val("${task.process}"), val('spring'), val('1.1.1'), topic: versions, emit: versions_spring
    tuple val("${task.process}"), val('megahit'), eval("megahit -v | sed 's/MEGAHIT v//'"), topic: versions, emit: versions_megahit

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    def spring_out      = meta.single_end ? "${prefix}.fastq.gz" : "${prefix}_R1.fastq.gz ${prefix}_R2.fastq.gz"
    def megahit_reads   = meta.single_end ? "-r ${prefix}.fastq.gz" : "-1 ${prefix}_R1.fastq.gz -2 ${prefix}_R2.fastq.gz"
    """
    ### Extract spring archive
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped-fastq \\
        --num-threads ${task.cpus}

    ### Megahit assembly
    megahit \\
        -t ${task.cpus} \\
        ${args} \\
        ${megahit_reads} \\
        --out-prefix ${prefix}

    ### Compress
    gzip -c megahit_out/*.fa > ${prefix}.contigs.fna.gz

    ### Cleanup
    rm -rf megahit_out/ *.fastq.gz
    """
}
