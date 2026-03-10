process READ_DOWNLOAD {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2bc1e94834d132c6d67b966efbd722e240ffc802187944e739f761a94124ed9/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-e9a85263ce475576_1?_gl=1*zvfk8*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTU1NzczMTA4LjE3NjYxNzI5NzguMTc2NjE3Mjk3OA..
    // xsra binary created via: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh; cargo install xsra
    storeDir "${params.output_dir}/${params.new_release_id}_outputs/preprocess/${meta.id}"

    input:
    tuple val(meta) , val(acc)
    path(index)

    output:
    tuple val(meta), path("${meta.id}.spring*") , emit: spring
    tuple val(meta), path("read*")              , emit: pe_count
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    """
    ### Download with xsra
    xsra dump \\
        ${acc} \\
        --outdir ${acc}/ \\
        --split \\
        --prefix ${acc}_ \\
        --compression g \\
        --threads ${task.cpus}

    if ls ${acc}/${acc}_1.fq.gz 1> /dev/null 2>&1; then
        mv ${acc}/*_0.fq.gz ${acc}/${acc}_R1.fastq.gz
        mv ${acc}/*_1.fq.gz ${acc}/${acc}_R2.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}_R1.fastq.gz --in2 ${acc}/${acc}_R2.fastq.gz"
        fastp_reads_out="--out1 ${acc}_R1.fastp.fastq.gz --out2 ${acc}_R2.fastp.fastq.gz"
        deacon_reads_in="${acc}_R1.fastp.fastq.gz ${acc}_R2.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}_R1.deacon.fastq.gz --output2 ${acc}_R2.deacon.fastq.gz"
        spring_input="${acc}_R1.deacon.fastq.gz ${acc}_R2.deacon.fastq.gz"
        touch read1
        touch read2
    else
        mv ${acc}/*_0.fq.gz ${acc}/${acc}.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}.fastq.gz"
        fastp_reads_out="--out1 ${acc}.fastp.fastq.gz"
        deacon_reads_in="${acc}.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}.deacon.fastq.gz"
        spring_input="${acc}.deacon.fastq.gz"
        touch read1
    fi

    ### Run fastp
    fastp \\
        \${fastp_reads_in} \\
        \${fastp_reads_out} \\
        --json ${meta.id}.fastp.json \\
        --html ${meta.id}.fastp.html \\
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
        --output-file ${meta.id}.spring

    ### Cleanup
    rm -rf ${meta.id}*deacon*.fastq.gz *.fastp.html *.fastp.json ${acc}/
    """
}
