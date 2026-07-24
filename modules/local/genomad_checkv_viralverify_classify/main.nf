String genomadCheckvViralverifyClassify(
    String prefix,
    int cpus,
    String genomad_fasta,
    String genomad_db,
    String checkv_db,
    String viralverify_db,
    String dtr_arg,
    String source_db,
    String db_type,
    String body_site
) {
    def genomad_filter = [
        '( ( $virus_score >= 0.7 && $length >= 2000 ) || ( $taxonomy =~ "Inoviridae" ) )',
        '&& !( $taxonomy =~ "Caudoviricetes" && $length < 10000 )',
        '&& !( $taxonomy =~ "Inoviridae" && ( $length < 4500 || $length > 12500 ) )',
        '&& !( $taxonomy == "Unclassified" )',
        '&& ( ( $taxonomy =~ "viricetes" ) || ( $taxonomy =~ "Anelloviridae" ) )',
    ].join(' ')

    def checkv_filter = [
        '( $aai_completeness >= 50 )',
        '&& ( $kmer_freq <= 1.2 )',
        '&& ( $contig_length / $aai_expected_length <= 1.5 )',
    ].join(' ')

    return """
    ### Run geNomad
    genomad \\
        end-to-end \\
        ${genomad_fasta} \\
        genomad_results \\
        ${genomad_db} \\
        --threads ${cpus} \\
        --relaxed --splits 5

    gzip -c genomad_results/*_summary/*_virus_summary.tsv > ${prefix}_virus_summary.tsv.gz
    gzip -c genomad_results/*_summary/*_virus_genes.tsv > ${prefix}_virus_genes.tsv.gz

    csvtk filter2 \\
        ${prefix}_virus_summary.tsv.gz \\
        --num-cpus ${cpus} \\
        --tabs \\
        --filter '${genomad_filter}' \\
        | csvtk cut --tabs -f seq_name --out-delimiter '\t' \\
        --out-file ${prefix}_filtered_genomad.txt

    seqkit grep \\
        genomad_results/*_summary/*_virus.fna \\
        --threads ${cpus} \\
        --pattern-file ${prefix}_filtered_genomad.txt \\
        --out-file ${prefix}_virus.fna.gz

    ### Run CheckV
    checkv \\
        end_to_end \\
        -t ${cpus} \\
        -d ${checkv_db} \\
        ${prefix}_virus.fna.gz \\
        ${prefix}_checkv

    gzip -c ${prefix}_checkv/quality_summary.tsv > ${prefix}_quality_summary.tsv.gz
    gzip -c ${prefix}_checkv/completeness.tsv > ${prefix}_completeness.tsv.gz

    seqkit replace \\
        ${prefix}_checkv/proviruses.fna \\
        --pattern "(_\\d\\s.*)" \\
        --replacement "" \\
        --threads ${cpus} \\
        --out-file ${prefix}_proviruses_fix.fna

    cat ${prefix}_proviruses_fix.fna ${prefix}_checkv/viruses.fna > ${prefix}_viruses.fna

    csvtk filter2 \\
        ${prefix}_checkv/completeness.tsv \\
        --num-cpus ${cpus} \\
        --tabs \\
        --filter '${checkv_filter}' \\
        | csvtk cut --tabs -f contig_id --out-delimiter '\t' \\
        --out-file ${prefix}_filtered_checkv.txt

    seqkit grep \\
        ${prefix}_viruses.fna \\
        --threads ${cpus} \\
        --pattern-file ${prefix}_filtered_checkv.txt \\
        --out-file ${prefix}_viruses_filtered.fna

    mv ${prefix}_viruses_filtered.fna ${prefix}_viruses.fna

    ### Run ViralVerify
    viralverify \\
        -f ${prefix}_viruses.fna \\
        --hmm ${viralverify_db} \\
        -o ${prefix}_viralverify \\
        -t ${cpus}

    gzip -c ${prefix}_viralverify/${prefix}_viruses_result_table.csv > ${prefix}_result_table.csv.gz
    gzip -c ${prefix}_viralverify/${prefix}_viruses_domtblout > ${prefix}_domtblout.gz

    ### Run UHVDB classify
    uhvdb_classify.py \\
        --fasta ${prefix}_viruses.fna \\
        --virus_summary ${prefix}_virus_summary.tsv.gz \\
        --genes ${prefix}_virus_genes.tsv.gz \\
        --quality_summary ${prefix}_quality_summary.tsv.gz \\
        --completeness ${prefix}_completeness.tsv.gz \\
        --viralverify ${prefix}_result_table.csv.gz \\
        ${dtr_arg} \\
        --output_confident_fasta ${prefix}.confident_uhvdb_viruses.fna \\
        --output_uncertain_fasta ${prefix}.uncertain_uhvdb_viruses.fna \\
        --output_complete_fasta ${prefix}.uhvdb_complete.fna \\
        --output_tsv ${prefix}.uhvdb_virus_class.tsv \\
        --source_db ${source_db} \\
        --db_type ${db_type} \\
        --body_site ${body_site}

    gzip ${prefix}.confident_uhvdb_viruses.fna
    gzip ${prefix}.uncertain_uhvdb_viruses.fna
    gzip ${prefix}.uhvdb_complete.fna
    gzip ${prefix}.uhvdb_virus_class.tsv

    ### Cleanup
    rm -rf genomad_results ${prefix}_checkv ${prefix}_viralverify tmp \\
        ${prefix}_virus.fna.gz ${prefix}_proviruses_fix.fna ${prefix}_viruses.fna \\
        ${prefix}_filtered_genomad.txt ${prefix}_filtered_checkv.txt \\
        ${prefix}_virus_summary.tsv.gz ${prefix}_virus_genes.tsv.gz \\
        ${prefix}_quality_summary.tsv.gz ${prefix}_completeness.tsv.gz \\
        ${prefix}_result_table.csv.gz ${prefix}_domtblout.gz
    """
}

process GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e93184e5d9fde3a001a2e44a8471db42262f14ca6dbf81d9256d789e96bdb71/data'
        : 'community.wave.seqera.io/library/genomad_checkv_viralverify_seqkit_pruned:c73505fd1e8794f8'}"

    input:
    tuple val(meta), path(fasta)
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
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), topic: versions, emit: versions_csvtk
    tuple val("${task.process}"), val('uhvdb_classify'), eval('uhvdb_classify.py --version'), topic: versions, emit: versions_uhvdb_classify

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def source_db = meta.source_db ?: 'NO_DB'
    def db_type = meta.db_type ?: 'Unspecified'
    def body_site = meta.body_site ?: 'Other'
    def dtr_arg = dtr_sequences_txt ? "--dtr_sequences ${dtr_sequences_txt}" : "--dtr_sequences ''"
    // Call sites may wrap a single FASTA in a list (e.g. [ fastx ])
    def genomad_fasta = (fasta instanceof List || fasta instanceof Collection) ? fasta[0].toString() : fasta.toString()
    def classify_cmd = genomadCheckvViralverifyClassify(
        prefix,
        task.cpus,
        genomad_fasta,
        genomad_db.toString(),
        checkv_db.toString(),
        viralverify_db.toString(),
        dtr_arg,
        source_db,
        db_type,
        body_site
    )
    """
    ${classify_cmd}
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
