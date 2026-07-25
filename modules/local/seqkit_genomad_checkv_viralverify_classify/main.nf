include { genomadCheckvViralverifyClassify } from '../genomad_checkv_viralverify_classify'

process SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b2/b21d6b0b33b8a74f05d75a717b01367cf9baed680c31e7af5c09599f62e05243/data'
        : 'community.wave.seqera.io/library/genomad_checkv_viralverify_seqkit_pruned:e8ba75f322d6bf62'}"

    input:
    tuple val(meta), val(id_files), path(fasta)
    path(genomad_db)
    path(checkv_db)
    path(viralverify_db)
    path(dtr_sequences_txt)
    path(hmm)
    path(hmm_tsv_gz)

    output:
    tuple val(meta), path("*.confident.fna.gz")     , emit: confident_fna_gz
    tuple val(meta), path("*.complete.fna.gz")      , emit: complete_fna_gz
    tuple val(meta), path("*.classify.tsv.gz")      , emit: classify_tsv_gz
    tuple val(meta), path("*.hcfilter.tsv.gz")      , emit: hcfilter_tsv_gz

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
        body_site,
        hmm.toString(),
        hmm_tsv_gz.toString()
    )
    """
    mkdir -p tmp

    while IFS=\$'\t' read -r sample_id file; do
        seqkit \\
            seq \\
            --threads ${task.cpus} \\
            --min-len 2000 \\
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
    echo "" | gzip > ${prefix}.confident.fna.gz
    echo "" | gzip > ${prefix}.complete.fna.gz
    echo "" | gzip > ${prefix}.classify.tsv.gz
    echo "" | gzip > ${prefix}.hcfilter.tsv.gz
    """
}
