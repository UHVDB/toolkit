process FASTP_DEACON_MEGAHIT {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cd/cd58329d0cc42aa2ab0ad4ce92bee4565b9b170edbe2c928b1c0adc7356412d5/data' :
        'community.wave.seqera.io/library/deacon_fastp_sracha_megahit_gzip:2df8c885cea541a4' }"

    input:
    tuple val(meta) , path(fastq)
    path(index)

    output:
    tuple val(meta), path("*.contigs.fna.gz") , emit: fna_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def fastp_reads_in      = meta.single_end ? "--in1 ${fastq}" : "--in1 ${fastq[0]} --in2 ${fastq[1]}"
    def fastp_reads_out     = meta.single_end ? "--out1 ${prefix}.fastp.fastq.gz" : "--out1 ${prefix}_1.fastp.fastq.gz --out2 ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_in     = meta.single_end ? "${prefix}.fastp.fastq.gz" : "${prefix}_1.fastp.fastq.gz ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_out    = meta.single_end ? "--output ${prefix}.deacon.fastq.gz" : "--output ${prefix}_1.deacon.fastq.gz --output2 ${prefix}_2.deacon.fastq.gz"
    def megahit_input       = meta.single_end ? "-r ${prefix}.deacon.fastq.gz" : "-1 ${prefix}_1.deacon.fastq.gz -2 ${prefix}_2.deacon.fastq.gz"
    """
    # run fastp
    fastp \\
        ${fastp_reads_in} \\
        ${fastp_reads_out} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe

    # run deacon
    deacon filter \\
        --deplete \\
        ${index} \\
        ${deacon_reads_in} \\
        ${deacon_reads_out} \\
        --threads ${task.cpus}

    rm -rf *.fastp.fastq.gz

    # run megahit
    megahit \\
        -t ${task.cpus} \\
        --min-contig-len 2000 \\
        ${megahit_input} \\
        --out-prefix ${prefix}

    # compress
    gzip -c megahit_out/*.fa > ${prefix}.contigs.fna.gz

    # cleanup
    rm -rf ${prefix}*deacon*.fastq.gz *.fastp.html *.fastp.json megahit_out/
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.contigs.fna.gz
    """
}
