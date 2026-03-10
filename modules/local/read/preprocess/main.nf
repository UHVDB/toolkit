process READ_PREPROCESS{
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2bc1e94834d132c6d67b966efbd722e240ffc802187944e739f761a94124ed9/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-e9a85263ce475576_1?_gl=1*zvfk8*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTU1NzczMTA4LjE3NjYxNzI5NzguMTc2NjE3Mjk3OA..
    storeDir "${params.output_dir}/${params.new_release_id}_outputs/preprocess/${meta.id}"

    input:
    tuple val(meta) , path(fastq)
    path(index)

    output:
    tuple val(meta), path("${meta.id}.spring*") , emit: spring
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    def fastp_reads_in      = meta.single_end ? "--in1 ${fastq}" : "--in1 ${fastq[0]} --in2 ${fastq[1]}"
    def fastp_reads_out     = meta.single_end ? "--out1 ${meta.id}.fastp.fastq.gz" : "--out1 ${meta.id}_1.fastp.fastq.gz --out2 ${meta.id}_2.fastp.fastq.gz"
    def deacon_reads_in     = meta.single_end ? "${meta.id}.fastp.fastq.gz" : "${meta.id}_1.fastp.fastq.gz ${meta.id}_2.fastp.fastq.gz"
    def deacon_reads_out    = meta.single_end ? "--output ${meta.id}.deacon.fastq.gz" : "--output ${meta.id}_1.deacon.fastq.gz --output2 ${meta.id}_2.deacon.fastq.gz"
    def spring_input        = meta.single_end ? "${meta.id}.deacon.fastq.gz" : "${meta.id}_1.deacon.fastq.gz ${meta.id}_2.deacon.fastq.gz"
    """
    ### Run fastp
    fastp \\
        ${fastp_reads_in} \\
        ${fastp_reads_out} \\
        --json ${meta.id}.fastp.json \\
        --html ${meta.id}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe

    ### Run deacon
    deacon filter \\
        --deplete \\
        ${index} \\
        ${deacon_reads_in} \\
        ${deacon_reads_out} \\
        --threads ${task.cpus}

    rm -rf *.fastp.fastq.gz

    ### Run spring
    spring \\
        --compress \\
        --input ${spring_input} \\
        --num-threads ${task.cpus} \\
        --quality-opts ill_bin \\
        --gzipped-fastq \\
        --allow-read-reordering \\
        --output-file ${meta.id}.spring

    ### Cleanup
    rm -rf ${meta.id}*deacon*.fastq.gz *.fastp.html *.fastp.json
    """
}
