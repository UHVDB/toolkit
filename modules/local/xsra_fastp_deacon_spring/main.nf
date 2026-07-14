process XSRA_FASTP_DEACON_SPRING {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/07/07f2814c3c48234ded08b489e77986b484886bf3a4b393b40017e7109d623d1b/data' :
        'community.wave.seqera.io/library/deacon_fastp_spring:cf5415ca9c1df5a8' }"
    // xsra is installed in the container via cargo (not available on bioconda)

    input:
    tuple val(meta) , val(acc)
    path(index)

    output:
    tuple val(meta), path("*.spring*") , emit: spring
    tuple val(meta), path("*.read*")   , emit: read_count
    tuple val("${task.process}"), val('xsra'), eval('xsra --version 2>&1 | sed -e "s/xsra //g"'), emit: versions_xsra, topic: versions
    tuple val("${task.process}"), val('fastp'), eval('fastp --version 2>&1 | sed -e "s/fastp //g"'), emit: versions_fastp, topic: versions
    tuple val("${task.process}"), val('deacon'), eval('deacon --version | head -n1 | sed "s/deacon //g"'), emit: versions_deacon, topic: versions
    tuple val("${task.process}"), val('spring'), val('1.1.1'), topic: versions, emit: versions_spring
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Download with xsra
    xsra dump \\
        ${acc} \\
        --outdir ${acc}/ \\
        --split \\
        --prefix ${acc}_ \\
        --compression g \\
        --threads ${task.cpus}

    ### Prepare fastp and deacon input and output files
    if ls ${acc}/${acc}_1.fq.gz 1> /dev/null 2>&1; then
        mv ${acc}/*_0.fq.gz ${acc}/${acc}_R1.fastq.gz
        mv ${acc}/*_1.fq.gz ${acc}/${acc}_R2.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}_R1.fastq.gz --in2 ${acc}/${acc}_R2.fastq.gz"
        fastp_reads_out="--out1 ${acc}_R1.fastp.fastq.gz --out2 ${acc}_R2.fastp.fastq.gz"
        deacon_reads_in="${acc}_R1.fastp.fastq.gz ${acc}_R2.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}_R1.deacon.fastq.gz --output2 ${acc}_R2.deacon.fastq.gz"
        spring_input="${acc}_R1.deacon.fastq.gz ${acc}_R2.deacon.fastq.gz"
        touch ${prefix}.read1
        touch ${prefix}.read2
    else
        mv ${acc}/*_0.fq.gz ${acc}/${acc}.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}.fastq.gz"
        fastp_reads_out="--out1 ${acc}.fastp.fastq.gz"
        deacon_reads_in="${acc}.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}.deacon.fastq.gz"
        spring_input="${acc}.deacon.fastq.gz"
        touch ${prefix}.read1
    fi

    ### Run fastp
    fastp \\
        \${fastp_reads_in} \\
        \${fastp_reads_out} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe

    ### Run deacon
    deacon filter \\
        --deplete \\
        ${index} \\
        \${deacon_reads_in} \\
        \${deacon_reads_out} \\
        --threads ${task.cpus}

    rm -rf *.fastp.fastq.gz

    ### Run spring
    spring \\
        --compress \\
        --input \${spring_input} \\
        --num-threads ${task.cpus} \\
        --quality-opts ill_bin \\
        --gzipped-fastq \\
        --output-file ${prefix}.spring

    ### Cleanup to save disk
    rm -rf *deacon*.fastq.gz *.fastp.html *.fastp.json ${acc}/
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.spring
    touch ${prefix}.read1
    touch ${prefix}.read2
    """
}
