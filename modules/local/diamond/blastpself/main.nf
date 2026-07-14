process DIAMOND_BLASTPSELF {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/diamond:2.1.23--hf93d47f_0'
        : 'quay.io/biocontainers/diamond:2.1.23--hf93d47f_0'}"

    input:
    tuple val(meta), path(faa_gz)

    output:
    tuple val(meta), path('*.{txt,txt.gz}'), emit: txt
    tuple val("${task.process}"), val('diamond'), eval('diamond --version 2>&1 | tail -n 1 | sed "s/^diamond version //"'), emit: versions_diamond, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Make diamond database from fasta file
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${faa_gz} \\
        -d ${prefix} \\
        ${args}

    ### Blast search against self
    diamond \\
        blastp \\
        --threads ${task.cpus} \\
        --db ${prefix}.dmnd \\
        --query ${faa_gz} \\
        --outfmt 6 \\
        ${args2} \\
        --out ${prefix}.txt

    ### Compress output
    gzip ${prefix}.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.txt.gz
    """
}
