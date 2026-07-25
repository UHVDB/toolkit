process DIAMOND_BLASTP {
    tag "${meta.id}.${meta2.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/diamond:2.1.23--hf93d47f_0'
        : 'quay.io/biocontainers/diamond:2.1.23--hf93d47f_0'}"

    input:
    tuple val(meta), path(fasta)
    tuple val(meta2), path(db)
    val outfmt
    val blast_columns

    output:
    tuple val(meta), path('*.{blast,blast.gz}'), optional: true, emit: blast
    tuple val(meta), path('*.{xml,xml.gz}'), optional: true, emit: xml
    tuple val(meta), path('*.{txt,txt.gz}'), optional: true, emit: txt
    tuple val(meta), path('*.{daa,daa.gz}'), optional: true, emit: daa
    tuple val(meta), path('*.{sam,sam.gz}'), optional: true, emit: sam
    tuple val(meta), path('*.{tsv,tsv.gz}'), optional: true, emit: tsv
    tuple val(meta), path('*.{paf,paf.gz}'), optional: true, emit: paf

    when:
    task.ext.when == null || task.ext.when

    script:
    meta = meta + [ db: meta2.id ]

    def prefix = task.ext.prefix ?: "${meta.id}.${meta2.id}"

    """
    diamond \\
        blastp \\
        --threads ${task.cpus} \\
        --db ${db} \\
        --query ${fasta} \\
        --outfmt 6 \\
        --compress 1 \\
        -k 0 -e 1e-3 --very-sensitive \\
        --out ${prefix}.txt.gz
    """

    stub:
    meta = meta + [ db: meta2.id ]

    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo "" | gzip > ${prefix}.txt.gz
    """
}
