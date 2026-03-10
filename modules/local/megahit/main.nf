process MEGAHIT {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/59/598ce470de069c60c8f0abeac848ff2f9faf2f4b4a3f83f42ff17136abc2d0e4/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-1d9be53c041f466d_1?_gl=1*hw8qg5*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.
    storeDir "${params.output_dir}/${params.new_release_id}_outputs/assemble/${meta.id}"

    input:
    tuple val(meta), path(spring)

    output:
    tuple val(meta), path("${meta.id}.contigs.fna.gz")  , emit: fna_gz
    tuple val(meta), path("${meta.id}.megahit.log.gz")  , emit: log_gz
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    def spring_out      = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    def megahit_reads   = meta.single_end ? "-r ${meta.id}.fastq.gz" : "-1 ${meta.id}_R1.fastq.gz -2 ${meta.id}_R2.fastq.gz"
    """
    ### Extract spring archive ###
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped-fastq \\
        --num-threads ${task.cpus}

    ### Megahit assembly ###
    megahit \\
        -t ${task.cpus} \\
        --k-list 21,29,39,59,79,99,119,141,163,185,207,229,251 \\
        ${megahit_reads} \\
        --out-prefix ${meta.id}

    ### Seqkit length filter and rename ###
    seqkit \\
        seq \\
        megahit_out/${meta.id}.contigs.fa \\
        --min-len 2000 \\
        --threads ${task.cpus} \\
    | seqkit replace -p "^" -r "${meta.id}_" --out-file ${meta.id}.contigs.fna.gz

    gzip -c megahit_out/*log > ${meta.id}.megahit.log.gz

    ### CLeanup ###
    rm -rf megahit_out/ *.fastq.gz
    """
}
