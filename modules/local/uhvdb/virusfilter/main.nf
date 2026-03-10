process UHVDB_VIRUSFILTER {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/20/20246727909eb49ec44fa645f8185ad4b39f2a41a519da236304ea6d805d71d7/data"

    input:
    tuple val(meta), path(fasta), path(virus_summary), path(genes), path(quality_summary), path(viralverify)
    path(dtr_sequences_txt)

    output:
    tuple val(meta), path("${meta.id}.uhvdb_viruses.fna.gz")    , emit: fna_gz
    tuple val(meta), path("${meta.id}.uhvdb_virus_class.tsv.gz"), emit: tsv_gz
    path ".command.log"                                         , emit: log
    path ".command.sh"                                          , emit: script

    script:
    def source_db = meta.source_db ?: 'no_source_db'
    def dtr_sequences = dtr_sequences_txt ? "--dtr_sequences ${dtr_sequences_txt}" : "--dtr_sequences ''"
    """
    uhvdb_virus_filter.py \\
        --fasta ${fasta} \\
        --virus_summary ${virus_summary} \\
        --genes ${genes} \\
        --quality_summary ${quality_summary} \\
        --viralverify ${viralverify} \\
        ${dtr_sequences} \\
        --output_fasta ${meta.id}.uhvdb_viruses.fna \\
        --output_tsv ${meta.id}.uhvdb_virus_class.tsv \\
        --source_db ${source_db}

    gzip ${meta.id}.uhvdb_viruses.fna
    gzip ${meta.id}.uhvdb_virus_class.tsv
    """
}
