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

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    # make diamond db
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in ${faa_gz} \\
        -d ${prefix}

    # diamond blastp
    diamond \\
        blastp \\
        --threads ${task.cpus} \\
        --db ${prefix}.dmnd \\
        --query ${faa_gz} \\
        --outfmt 6 \\
        -k 0 -e 1e-3 --very-sensitive \\
        --compress 1 \\
        --out ${prefix}.txt.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.txt.gz
    """
}
