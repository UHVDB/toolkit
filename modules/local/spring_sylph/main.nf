process SPRING_SYLPH {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e9/e99d8679b1d32f3519ba282468d675906d741bc1c278a091ce2986d36375cb32/data' :
        'community.wave.seqera.io/library/spring_sylph:95bacbb86b98f52e' }"

    input:
    tuple val(meta) , path(spring)
    path(db)

    output:
    tuple val(meta), path("*.profile.tsv")  , emit: tsv
    tuple val("${task.process}"), val('spring'), val('1.1.1'), topic: versions, emit: versions_spring
    tuple val("${task.process}"), val('sylph'), eval('sylph -V | sed "s/sylph //g"'), topic: versions, emit: versions_sylph

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def spring_out  = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    def sylph_reads = meta.single_end ? "-r ${meta.id}.fastq.gz" : "-1 ${meta.id}_R1.fastq.gz -2 ${meta.id}_R2.fastq.gz"
    """
    ### decompress spring
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped-fastq \\
        --num-threads ${task.cpus}

    ### run sylph profile
    sylph profile \\
        ${db} \\
        ${args} \\
        ${sylph_reads} \\
        -t ${task.cpus} \\
        --output-file ${prefix}.profile.tsv \\

    ### Cleanup
    rm -rf *.fastq.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.profile.tsv
    """
}
