process UHVDB_CLASSIFY {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ff/ff2c7e6a1d237f65056929cb69cf5301742780ff22a7f79d5b763c72874b8de6/data':
        'community.wave.seqera.io/library/biopython_polars:1c1d88559d24ac35' }"

    input:
    tuple val(meta), path(fasta), path(virus_summary), path(genes), path(quality_summary), path(completeness), path(viralverify)
    path(dtr_sequences_txt)

    output:
    tuple val(meta), path("*.confident_uhvdb_viruses.fna.gz"), emit: confident_fna_gz
    tuple val(meta), path("*.uncertain_uhvdb_viruses.fna.gz"), emit: uncertain_fna_gz
    tuple val(meta), path("*.uhvdb_complete.fna.gz")          , emit: complete_fna_gz
    tuple val(meta), path("*.uhvdb_virus_class.tsv.gz"), emit: tsv_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('biopython'), eval('python -c "import Bio; print(Bio.__version__)"'), topic: versions, emit: versions_biopython
    tuple val("${task.process}"), val('uhvdb_classify'), eval('uhvdb_classify.py --version'), topic: versions, emit: versions_uhvdb_classify

    when:
    task.ext.when == null || task.ext.when

    script:
    def source_db = meta.source_db ?: 'no_source_db'
    def db_type = meta.db_type ?: 'Unspecified'
    def body_site = meta.body_site ?: 'Other'
    def dtr_sequences = dtr_sequences_txt ? "--dtr_sequences ${dtr_sequences_txt}" : "--dtr_sequences ''"
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Run uhvdb_classify
    uhvdb_classify.py \\
        --fasta ${fasta} \\
        --virus_summary ${virus_summary} \\
        --genes ${genes} \\
        --quality_summary ${quality_summary} \\
        --completeness ${completeness} \\
        --viralverify ${viralverify} \\
        ${dtr_sequences} \\
        --output_confident_fasta ${prefix}.confident_uhvdb_viruses.fna \\
        --output_uncertain_fasta ${prefix}.uncertain_uhvdb_viruses.fna \\
        --output_complete_fasta ${prefix}.uhvdb_complete.fna \\
        --output_tsv ${prefix}.uhvdb_virus_class.tsv \\
        --source_db ${source_db} \\
        --db_type ${db_type} \\
        --body_site ${body_site}

    ### Compress
    gzip ${prefix}.confident_uhvdb_viruses.fna
    gzip ${prefix}.uncertain_uhvdb_viruses.fna
    gzip ${prefix}.uhvdb_complete.fna
    gzip ${prefix}.uhvdb_virus_class.tsv

    ### Cleanup
    rm -f ${prefix}.combined_viruses.fna
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Touch empty output files
    echo "" | gzip > ${prefix}.confident_uhvdb_viruses.fna.gz
    echo "" | gzip > ${prefix}.uncertain_uhvdb_viruses.fna.gz
    echo "" | gzip > ${prefix}.uhvdb_complete.fna.gz
    echo "" | gzip > ${prefix}.uhvdb_virus_class.tsv.gz
    """
}