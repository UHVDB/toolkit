process SRACHA_FASTP_DEACON_MEGAHIT {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cd/cd58329d0cc42aa2ab0ad4ce92bee4565b9b170edbe2c928b1c0adc7356412d5/data' :
        'community.wave.seqera.io/library/deacon_fastp_sracha_megahit_gzip:2df8c885cea541a4' }"

    input:
    tuple val(meta) , val(acc)
    path(index)

    output:
    tuple val(meta), path("*.contigs.fna.gz")  , emit: fna_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Download with sracha
    sracha get \\
        ${acc} \\
        --format sralite \\
        --threads ${task.cpus} \\
        --output-dir ${acc}/

    ### Prepare fastp and deacon input and output files
    if ls ${acc}/${acc}_2.fastq.gz 1> /dev/null 2>&1; then
        mv ${acc}/*_1.fastq.gz ${acc}/${acc}_R1.fastq.gz
        mv ${acc}/*_2.fastq.gz ${acc}/${acc}_R2.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}_R1.fastq.gz --in2 ${acc}/${acc}_R2.fastq.gz"
        fastp_reads_out="--out1 ${acc}_R1.fastp.fastq.gz --out2 ${acc}_R2.fastp.fastq.gz"
        deacon_reads_in="${acc}_R1.fastp.fastq.gz ${acc}_R2.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}_R1.deacon.fastq.gz --output2 ${acc}_R2.deacon.fastq.gz"
        megahit_input="-1 ${acc}_R1.deacon.fastq.gz -2 ${acc}_R2.deacon.fastq.gz"
    else
        mv ${acc}/*_1.fastq.gz ${acc}/${acc}.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}.fastq.gz"
        fastp_reads_out="--out1 ${acc}.fastp.fastq.gz"
        deacon_reads_in="${acc}.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}.deacon.fastq.gz"
        megahit_input="-r ${acc}.deacon.fastq.gz"
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

    ### Megahit assembly
    megahit \\
        -t ${task.cpus} \\
        --min-contig-len 2000 \\
        \${megahit_input} \\
        --out-prefix ${prefix}

    ### Compress
    gzip -c megahit_out/*.fa > ${prefix}.contigs.fna.gz

    ### Cleanup to save disk
    rm -rf *deacon*.fastq.gz *.fastp.html *.fastp.json ${acc}/ megahit_out/
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.contigs.fna.gz
    """
}
