include { genomadCheckvViralverifyClassify } from '../genomad_checkv_viralverify_classify'

process ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e93184e5d9fde3a001a2e44a8471db42262f14ca6dbf81d9256d789e96bdb71/data'
        : 'community.wave.seqera.io/library/genomad_checkv_viralverify_seqkit_pruned:c73505fd1e8794f8'}"

    input:
    tuple val(meta), val(id_urls)
    path(genomad_db)
    path(checkv_db)
    path(viralverify_db)
    path(dtr_sequences_txt)

    output:
    tuple val(meta), path("*.confident_uhvdb_viruses.fna.gz")   , emit: confident_fna_gz
    tuple val(meta), path("*.uncertain_uhvdb_viruses.fna.gz")   , emit: uncertain_fna_gz
    tuple val(meta), path("*.uhvdb_complete.fna.gz")            , emit: complete_fna_gz
    tuple val(meta), path("*.uhvdb_virus_class.tsv.gz")         , emit: tsv_gz
    tuple val("${task.process}"), val('genomad'), eval("genomad --version 2>&1 | sed 's/^.*geNomad, version //; s/ .*//'"), topic: versions, emit: versions_genomad
    tuple val("${task.process}"), val('checkv'), eval("checkv -h 2>&1 | sed '1!d;s/^.*CheckV v//;s/:.*//'"), topic: versions, emit: versions_checkv
    tuple val("${task.process}"), val('viralverify'), val('1.1'), emit: versions_viralverify, topic: versions
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val("aria2"), eval("aria2c --version 2>&1 | sed -n 's/^aria2 version \\([^ ]*\\).*/\\1/p'"), emit: versions_aria2, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), topic: versions, emit: versions_csvtk
    tuple val("${task.process}"), val('uhvdb_classify'), eval('uhvdb_classify.py --version'), topic: versions, emit: versions_uhvdb_classify

    script:
    def url_list = id_urls.collect { id_url -> id_url[1].toString() + ',\sout=' + id_url[0].toString() + '.fna.gz' }.join(',')
    def prefix = task.ext.prefix ?: "${meta.id}"
    def source_db = meta.source_db ?: 'no_source_db'
    def db_type = meta.db_type ?: 'Unspecified'
    def body_site = meta.body_site ?: 'Other'
    def dtr_arg = dtr_sequences_txt ? "--dtr_sequences ${dtr_sequences_txt}" : "--dtr_sequences ''"
    def classify_cmd = genomadCheckvViralverifyClassify(
        prefix,
        task.cpus,
        'combined_filtered.fasta.gz',
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
    IFS=',' read -r -a download_array <<< "${url_list}"
    printf '%s\\n' "\${download_array[@]}" > aria2_file.tsv

    for try in {1..6}; do
        aria2c \\
            --input=aria2_file.tsv \\
            --dir=tmp/ \\
            --max-connection-per-server=${task.cpus} \\
            --split=${task.cpus} \\
            --max-tries=10 \\
            --retry-wait=30 \\
            --max-concurrent-downloads=${task.cpus} && break || sleep \$((\$try^2*60))
    done

    for file in tmp/*.fna.gz; do
        sample_id=\$(basename \${file} .fna.gz)

        seqkit \\
            seq \\
            --threads ${task.cpus} \\
            --min-len ${params.min_seq_length} \\
            \$file \\
        | seqkit replace \\
            --threads ${task.cpus} \\
            -p ^ -r "\${sample_id}_" \\
            --out-file \${sample_id}.fna.gz

        rm \$file
    done

    cat ./*.fna.gz > combined_filtered.fasta.gz

    ${classify_cmd}

    rm -f combined_filtered.fasta.gz aria2_file.tsv tmp/*.fna.gz
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
