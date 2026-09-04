String mvirsPropagateVclust(
    String prefix,
    int cpus,
    String assembly_fna,
    String classify_tsv,
    String confident_fna,
    String species_reps,
    String ignore,
    String min_ani,
    String min_qcov
) {
    return """
    ### Keep this sample's confident/uncertain classify rows
    csvtk filter2 \\
        ${classify_tsv} \\
        --num-cpus ${cpus} \\
        --tabs \\
        --filter '( \$seq_name =~ "^${prefix}_" ) && ( ( \$uhvdb_virus_classification == "confident" ) || ( \$uhvdb_virus_classification == "uncertain" ) )' \\
        --out-file ${prefix}.sample_classify.tsv

    ### Parent contig IDs (strip |provirus coordinates; keep sample prefix)
    awk -F '\\t' 'NR > 1 {
        name = \$1
        sub(/\\|.*\$/, "", name)
        print name
    }' ${prefix}.sample_classify.tsv | sort -u > ${prefix}.virus_prefixed.txt

    ### Map classify names back to unprefixed assembly headers
    sed "s/^${prefix}_//" ${prefix}.virus_prefixed.txt > ${prefix}.virus_assembly.txt

    if [ -s ${prefix}.virus_assembly.txt ]; then
        seqkit grep \\
            ${assembly_fna} \\
            --threads ${cpus} \\
            --pattern-file ${prefix}.virus_assembly.txt \\
            --out-file ${prefix}.virus_unprefixed.fna.gz

        seqkit replace \\
            ${prefix}.virus_unprefixed.fna.gz \\
            --threads ${cpus} \\
            --pattern "^" \\
            --replacement "${prefix}_" \\
        | seqkit seq \\
            --only-id \\
            --out-file ${prefix}.virus_genomes.fna.gz
    else
        echo "" | gzip > ${prefix}.virus_genomes.fna.gz
    fi

    ### Confident viruses for vClust (already this sample)
    if [ -s "${confident_fna}" ]; then
        cp -f ${confident_fna} ${prefix}.confident_viruses.fna.gz
    else
        echo "" | gzip > ${prefix}.confident_viruses.fna.gz
    fi

    touch ${prefix}.mvirs.fasta
    touch ${prefix}.mvirs.bam
    touch ${prefix}.propagate.tsv
    touch ${prefix}.ani.tsv
    touch ${prefix}.gani.tsv

    ### Run mVIRs on paired-end reads when viral parent contigs are present
    if [ \$(zgrep -c "^>" ${prefix}.virus_genomes.fna.gz || true) -eq 0 ]; then
        echo "No viral genomes detected. Skipping mVIRs."
    elif [ "\${is_paired}" -eq 0 ]; then
        echo "Reads not paired-end. Skipping mVIRs."
    else
        mvirs index \\
            -f ${prefix}.virus_genomes.fna.gz

        first_id=\$(seqkit head -n 1 \${first_fastq} | seqkit seq -n | awk '{ print \$1 }' || true)
        if [[ "\$first_id" =~ [/.][12]\$ ]]; then
            mvirs_fix.py oprs \\
                -db ${prefix}.virus_genomes.fna.gz \\
                \${mvirs_reads} \\
                -t ${cpus} \\
                -o ${prefix}.mvirs \\
                -m \\
                ${ignore}
        else
            mvirs oprs \\
                -db ${prefix}.virus_genomes.fna.gz \\
                \${mvirs_reads} \\
                -t ${cpus} \\
                -o ${prefix}.mvirs \\
                -m \\
                ${ignore}
        fi
        touch ${prefix}.mvirs.fasta
    fi

    ### Convert classify provirus rows to Propagate coordinates
    echo -e "scaffold\\tfragment\\tstart\\tstop" > ${prefix}.coords.tsv
    awk -F '\\t' 'NR > 1 && \$1 ~ /\\|provirus/' ${prefix}.sample_classify.tsv \\
        | sed -E 's/(^[^|]+)\\|provirus_([0-9]+)_([0-9]+).*/\\1\\t\\1|provirus_\\2_\\3\\t\\2\\t\\3/' \\
        >> ${prefix}.coords.tsv || true

    gzip -cd ${prefix}.virus_genomes.fna.gz > ${prefix}.virus_genomes.fna

    ### Run Propagate on the mVIRs BAM when proviruses are present
    if [ "\$(grep -c '^' ${prefix}.coords.tsv)" -eq 1 ] \\
        || [ "\$(grep -c '^>' ${prefix}.virus_genomes.fna || true)" -eq 0 ] \\
        || [ ! -s ${prefix}.mvirs.bam ]; then
        echo "No proviruses or mVIRs BAM. Skipping Propagate."
    else
        ### Skip BAM records with query_length 0 (Propagate add_depth)
        Propagate \\
            -f ${prefix}.virus_genomes.fna \\
            -v ${prefix}.coords.tsv \\
            -b ${prefix}.mvirs.bam \\
            -o ${prefix}.propagate \\
            -t ${cpus}

        touch ${prefix}.propagate.tsv
        if [ -f ${prefix}.propagate/${prefix}.propagate.tsv ]; then
            mv ${prefix}.propagate/${prefix}.propagate.tsv ${prefix}.propagate.tsv
        fi
    fi

    ### Align this sample's confident viruses to UHVDB species reps
    if [ \$(zgrep -c "^>" ${prefix}.confident_viruses.fna.gz || true) -eq 0 ]; then
        echo "No confident viruses. Skipping vClust new2all."
    else
        echo "${species_reps}" >| ref_kdb.txt

        kmer-db \\
            build \\
            -k 25 -f 0.2 \\
            -t ${cpus} \\
            -multisample-fasta \\
            ref_kdb.txt \\
            ref.kdb

        echo "${prefix}.confident_viruses.fna.gz" >| query_kdb.txt

        kmer-db \\
            new2all \\
            -sparse \\
            -min num-kmers:20 -min ani-shorter:${min_ani} \\
            -t ${cpus} \\
            -multisample-fasta \\
            ref.kdb \\
            query_kdb.txt \\
            query_v_ref.csv

        kmer-db \\
            distance \\
            ani-shorter \\
            -sparse \\
            -min ${min_ani} \\
            -t ${cpus} \\
            query_v_ref.csv \\
            query_v_ref.dist.csv

        kmerdb_to_lzani.py \\
            -i query_v_ref.dist.csv \\
            -o query_v_ref.dist_mod.csv

        zcat ${species_reps} >| ref_query.combined.fna
        zcat ${prefix}.confident_viruses.fna.gz >> ref_query.combined.fna

        lz-ani \\
            all2all \\
            --in-fasta ref_query.combined.fna \\
            -o ${prefix}.ani.tsv \\
            --out-format query,reference,gani,ani,qcov,rcov \\
            -t ${cpus} \\
            --multisample-fasta true \\
            --out-type tsv \\
            --flt-kmerdb query_v_ref.dist_mod.csv ${min_ani} \\
            --out-filter ani ${min_ani} \\
            --out-filter qcov ${min_qcov}

        csvtk cut \\
            ${prefix}.ani.tsv \\
            --tabs \\
            --delete-header \\
            --fields query,reference,gani \\
            --out-file ${prefix}.gani.tsv || touch ${prefix}.gani.tsv
    fi

    gzip -f ${prefix}.mvirs.fasta
    gzip -f ${prefix}.propagate.tsv
    gzip -f ${prefix}.ani.tsv
    gzip -f ${prefix}.gani.tsv

    ### Cleanup
    rm -rf ${prefix}.propagate ref.kdb ref_kdb.txt query_kdb.txt \\
        query_v_ref.csv query_v_ref.dist.csv query_v_ref.dist_mod.csv \\
        ref_query.combined.fna ${prefix}.virus_genomes.fna \\
        ${prefix}.virus_unprefixed.fna.gz ${prefix}.virus_genomes.fna.gz \\
        ${prefix}.confident_viruses.fna.gz ${prefix}.sample_classify.tsv \\
        ${prefix}.virus_prefixed.txt ${prefix}.virus_assembly.txt \\
        ${prefix}.coords.tsv ${prefix}.mvirs.bam ${prefix}.mvirs.clipped \\
        ${prefix}.mvirs.oprs ${prefix}.virus_genomes.fna.gz.* \\
        *deacon*.fastq.gz *.fastp.html *.fastp.json
    """
}

process FASTP_DEACON_MVIRS_PROPAGATE_VCLUST {
    tag "${meta.id}"
    label 'process_super_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b35e98507506ad91f67a5cb44089d7b14d7b794291b99c2cc0e866c72d29355/data' :
        'community.wave.seqera.io/library/sracha_fastp_deacon_mvirs_pruned:45403beba8693cd2' }"

    input:
    tuple val(meta), path(fastq), path(assembly_fna), path(classify_tsv), path(confident_fna)
    path(index)
    path(species_reps)

    output:
    tuple val(meta), path("*.mvirs.fasta.gz")   , emit: mvirs_fasta_gz
    tuple val(meta), path("*.propagate.tsv.gz") , emit: propagate_tsv_gz
    tuple val(meta), path("*.ani.tsv.gz")       , emit: ani_tsv_gz
    tuple val(meta), path("*.gani.tsv.gz")      , emit: gani_tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def ignore = task.attempt == 3 ? "|| true" : ""
    def fastp_reads_in   = meta.single_end ? "--in1 ${fastq}" : "--in1 ${fastq[0]} --in2 ${fastq[1]}"
    def fastp_reads_out  = meta.single_end ? "--out1 ${prefix}.fastp.fastq.gz" : "--out1 ${prefix}_1.fastp.fastq.gz --out2 ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_in  = meta.single_end ? "${prefix}.fastp.fastq.gz" : "${prefix}_1.fastp.fastq.gz ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_out = meta.single_end ? "--output ${prefix}.deacon.fastq.gz" : "--output ${prefix}_1.deacon.fastq.gz --output2 ${prefix}_2.deacon.fastq.gz"
    def mvirs_reads      = meta.single_end ? "-r ${prefix}.deacon.fastq.gz" : "-f ${prefix}_1.deacon.fastq.gz -r ${prefix}_2.deacon.fastq.gz"
    def first_fastq      = meta.single_end ? "${prefix}.deacon.fastq.gz" : "${prefix}_1.deacon.fastq.gz"
    def is_paired        = meta.single_end ? "0" : "1"
    def analyze_cmd = mvirsPropagateVclust(
        prefix,
        task.cpus,
        assembly_fna.toString(),
        classify_tsv.toString(),
        confident_fna ? confident_fna.toString() : "",
        species_reps.toString(),
        ignore,
        "0.7",
        "0.0"
    )
    """
    ### Run fastp
    fastp \\
        ${fastp_reads_in} \\
        ${fastp_reads_out} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe

    ### Run deacon
    deacon filter \\
        --deplete \\
        ${index} \\
        ${deacon_reads_in} \\
        ${deacon_reads_out} \\
        --threads ${task.cpus}

    rm -rf *.fastp.fastq.gz

    mvirs_reads="${mvirs_reads}"
    first_fastq="${first_fastq}"
    is_paired=${is_paired}

    ### Virus FASTA IDs only; Propagate skips zero-length BAM queries
    ${analyze_cmd}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.mvirs.fasta.gz
    echo "" | gzip > ${prefix}.propagate.tsv.gz
    echo "" | gzip > ${prefix}.ani.tsv.gz
    echo "" | gzip > ${prefix}.gani.tsv.gz
    """
}
