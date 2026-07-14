include { genomadCheckvViralverifyClassify } from '../genomad_checkv_viralverify_classify'

process SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e93184e5d9fde3a001a2e44a8471db42262f14ca6dbf81d9256d789e96bdb71/data'
        : 'community.wave.seqera.io/library/genomad_checkv_viralverify_seqkit_pruned:c73505fd1e8794f8'}"

    input:
    tuple val(meta), val(id_files), path(fasta)
    path(genomad_db)
    path(checkv_db)
    path(viralverify_db)
    path(dtr_sequences_txt)

    output:
    tuple val(meta), path("*.confident_uhvdb_viruses.fna.gz"), emit: confident_fna_gz
    tuple val(meta), path("*.uncertain_uhvdb_viruses.fna.gz"), emit: uncertain_fna_gz
    tuple val(meta), path("*.uhvdb_complete.fna.gz")          , emit: complete_fna_gz
    tuple val(meta), path("*.uhvdb_virus_class.tsv.gz"), emit: tsv_gz
    tuple val("${task.process}"), val('genomad'), eval("genomad --version 2>&1 | sed 's/^.*geNomad, version //; s/ .*//'"), topic: versions, emit: versions_genomad
    tuple val("${task.process}"), val('checkv'), eval("checkv -h 2>&1 | sed '1!d;s/^.*CheckV v//;s/:.*//'"), topic: versions, emit: versions_checkv
    tuple val("${task.process}"), val('viralverify'), val('1.1'), emit: versions_viralverify, topic: versions
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), topic: versions, emit: versions_csvtk
    tuple val("${task.process}"), val('uhvdb_classify'), eval('uhvdb_classify.py --version'), topic: versions, emit: versions_uhvdb_classify

    script:
    def records = id_files.collect { id, path -> "${id}\t${file(path).name}" }.join('\n')
    def prefix = task.ext.prefix ?: "${meta.id}"
    def source_db = meta.source_db ?: 'no_source_db'
    def db_type = meta.db_type ?: 'Unspecified'
    def body_site = meta.body_site ?: 'Other'
    def dtr_arg = dtr_sequences_txt ? "--dtr_sequences ${dtr_sequences_txt}" : "--dtr_sequences ''"
    def classify_cmd = genomadCheckvViralverifyClassify(
        prefix,
        task.cpus,
        "${prefix}_combined_filtered.fasta.gz",
        genomad_db.toString(),
        checkv_db.toString(),
        viralverify_db.toString(),
        dtr_arg,
        source_db,
        db_type,
        body_site
    )
    """
    mkdir -p tmp

    while IFS=\$'\t' read -r sample_id file; do
        seqkit \\
            seq \\
            --threads ${task.cpus} \\
            --min-len ${params.min_seq_length} \\
            "\${file}" \\
        | seqkit replace \\
            --threads ${task.cpus} \\
            -p ^ -r "\${sample_id}_" \\
            --out-file "tmp/\${sample_id}.fna.gz"
    done <<'RECORDS'
    ${records}
    RECORDS

    cat tmp/*.fna.gz > ${prefix}_combined_filtered.fasta.gz

    ${classify_cmd}

    rm -f ${prefix}_combined_filtered.fasta.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.confident_uhvdb_viruses.fna.gz
    echo "" | gzip > ${prefix}.uncertain_uhvdb_viruses.fna.gz
    echo "" | gzip > ${prefix}.uhvdb_complete.fna.gz
    echo "" | gzip > ${prefix}.uhvdb_virus_class.tsv.gz
    """
}
