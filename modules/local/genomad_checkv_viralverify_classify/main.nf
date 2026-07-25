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
    String body_site,
    String hmm,
    String hmm_tsv_gz
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
    # run genomad
    genomad \\
        end-to-end \\
        ${genomad_fasta} \\
        genomad_results \\
        ${genomad_db} \\
        --threads ${cpus} \\
        --relaxed --splits 5

    gzip -c genomad_results/*_summary/*_virus_summary.tsv > ${prefix}_virus_summary.tsv.gz
    gzip -c genomad_results/*_summary/*_virus_genes.tsv > ${prefix}_virus_genes.tsv.gz

    # filter genomad results
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

    # run checkv
    checkv \\
        end_to_end \\
        -t ${cpus} \\
        -d ${checkv_db} \\
        ${prefix}_virus.fna.gz \\
        ${prefix}_checkv

    gzip -c ${prefix}_checkv/quality_summary.tsv > ${prefix}_quality_summary.tsv.gz
    gzip -c ${prefix}_checkv/completeness.tsv > ${prefix}_completeness.tsv.gz

    # fix provirus names
    seqkit replace \\
        ${prefix}_checkv/proviruses.fna \\
        --pattern "(_\\d\\s.*)" \\
        --replacement "" \\
        --threads ${cpus} \\
        --out-file ${prefix}_proviruses_fix.fna

    cat ${prefix}_proviruses_fix.fna ${prefix}_checkv/viruses.fna > ${prefix}_viruses.fna

    # filter checkv results
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

    # run viralverify
    viralverify \\
        -f ${prefix}_viruses.fna \\
        --hmm ${viralverify_db} \\
        -o ${prefix}_viralverify \\
        -t ${cpus}

    gzip -c ${prefix}_viralverify/${prefix}_viruses_result_table.csv > ${prefix}_result_table.csv.gz
    gzip -c ${prefix}_viralverify/${prefix}_viruses_domtblout > ${prefix}_domtblout.gz

    # run uhvdb classify
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
        --output_complete_fasta ${prefix}.complete.fna \\
        --output_tsv ${prefix}.classify.tsv \\
        --source_db ${source_db} \\
        --db_type ${db_type} \\
        --body_site ${body_site}

    # skip pyrodigal-gv / hmmsearch / hcfilter when uncertain fasta has no sequences
    if grep -q '^>' ${prefix}.uncertain_uhvdb_viruses.fna 2>/dev/null; then
        pyrodigal-gv \\
            -i ${prefix}.uncertain_uhvdb_viruses.fna \\
            -a ${prefix}.pyrodigalgv.faa \\
            --jobs ${cpus} &> /dev/null

        hmmsearch --noali \\
            -o /dev/null \\
            -E 1e-5 \\
            --tblout ${prefix}_v_genomad_hallmarks.tbl \\
            --cpu ${cpus} \\
            ${hmm} \\
            ${prefix}.pyrodigalgv.faa \\
            2> hmmsearch.log

        uhvdb_hcfilter.py \\
            --hmmsearch_tbl ${prefix}_v_genomad_hallmarks.tbl \\
            --genomad_tsv ${hmm_tsv_gz} \\
            --fasta ${prefix}.uncertain_uhvdb_viruses.fna \\
            --output_tsv ${prefix}.hcfilter.tsv \\
            --output_fasta ${prefix}.hcfilter.fna
    else
        touch ${prefix}.hcfilter.fna
        printf 'contig_id\\tvirus_hallmarks\\tplasmid_hallmarks\\n' > ${prefix}.hcfilter.tsv
    fi

    cat ${prefix}.confident_uhvdb_viruses.fna ${prefix}.hcfilter.fna > ${prefix}.confident.fna

    gzip ${prefix}.confident.fna
    gzip ${prefix}.complete.fna
    gzip ${prefix}.classify.tsv
    gzip ${prefix}.hcfilter.tsv

    ### Cleanup
    rm -rf genomad_results ${prefix}_checkv ${prefix}_viralverify tmp \\
        ${prefix}_virus.fna.gz ${prefix}_proviruses_fix.fna ${prefix}_viruses.fna \\
        ${prefix}_filtered_genomad.txt ${prefix}_filtered_checkv.txt \\
        ${prefix}_virus_summary.tsv.gz ${prefix}_virus_genes.tsv.gz \\
        ${prefix}_quality_summary.tsv.gz ${prefix}_completeness.tsv.gz \\
        ${prefix}_result_table.csv.gz ${prefix}_domtblout.gz \\
        ${prefix}.confident_uhvdb_viruses.fna ${prefix}.uncertain_uhvdb_viruses.fna \\
        ${prefix}.pyrodigalgv.faa ${prefix}.hcfilter.fna \\
        ${prefix}_v_genomad_hallmarks.tbl hmmsearch.log
    """
}

process GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b2/b21d6b0b33b8a74f05d75a717b01367cf9baed680c31e7af5c09599f62e05243/data'
        : 'community.wave.seqera.io/library/genomad_checkv_viralverify_seqkit_pruned:e8ba75f322d6bf62'}"

    input:
    tuple val(meta), path(fasta)
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
        body_site,
        hmm.toString(),
        hmm_tsv_gz.toString()
    )
    """
    ${classify_cmd}
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
