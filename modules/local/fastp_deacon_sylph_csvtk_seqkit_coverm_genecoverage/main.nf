process FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/52/52ad81311482c929788188ff95f0c458ea8e5b4ba3d13ab316dff725a27f4dba/data' :
        'community.wave.seqera.io/library/sracha_fastp_deacon_sylph_pruned:38fbe21bf5eb32c7' }"

    input:
    tuple val(meta), path(fastq)
    path(index)
    path(db)
    path(species_reps_fna_gz)
    path(annotations)
    path(pilea_db)

    output:
    tuple val(meta), path("*.profile.tsv")              , emit: tsv
    tuple val(meta), path("*.depth.tsv.gz")             , emit: depth_tsv_gz         , optional: true
    tuple val(meta), path("*.gene_coverage.tsv.gz")     , emit: gene_coverage_tsv_gz , optional: true
    tuple val(meta), path("*.output.tsv")               , emit: pilea_tsv

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def fastp_reads_in   = meta.single_end ? "--in1 ${fastq}" : "--in1 ${fastq[0]} --in2 ${fastq[1]}"
    def fastp_reads_out  = meta.single_end ? "--out1 ${prefix}.fastp.fastq.gz" : "--out1 ${prefix}_1.fastp.fastq.gz --out2 ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_in  = meta.single_end ? "${prefix}.fastp.fastq.gz" : "${prefix}_1.fastp.fastq.gz ${prefix}_2.fastp.fastq.gz"
    def deacon_reads_out = meta.single_end ? "--output ${prefix}.deacon.fastq.gz" : "--output ${prefix}_1.deacon.fastq.gz --output2 ${prefix}_2.deacon.fastq.gz"
    def sylph_reads      = meta.single_end ? "-r ${prefix}.deacon.fastq.gz" : "-1 ${prefix}_1.deacon.fastq.gz -2 ${prefix}_2.deacon.fastq.gz"
    def coverm_reads     = meta.single_end ? "--single ${prefix}.deacon.fastq.gz" : "--coupled ${prefix}_1.deacon.fastq.gz ${prefix}_2.deacon.fastq.gz"
    // Symlink to *_R1/*_R2.fastq.gz so pilea pairs mates (*.deacon.fastq.gz breaks pairing)
    def pilea_link_r1    = meta.single_end ? "ln -sf ${prefix}.deacon.fastq.gz ${prefix}.fastq.gz" : "ln -sf ${prefix}_1.deacon.fastq.gz ${prefix}_R1.fastq.gz"
    def pilea_link_r2    = meta.single_end ? "" : "ln -sf ${prefix}_2.deacon.fastq.gz ${prefix}_R2.fastq.gz"
    def pilea_reads      = meta.single_end ? "--single ${prefix}.fastq.gz" : "${prefix}_R1.fastq.gz ${prefix}_R2.fastq.gz"
    def pilea_cleanup    = meta.single_end ? "${prefix}.fastq.gz" : "${prefix}_R1.fastq.gz ${prefix}_R2.fastq.gz"
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

    ### Run sylph profile
    sylph profile \\
        ${db} \\
        --min-number-kmers 3 \\
        --estimate-unknown \\
        ${sylph_reads} \\
        -t ${task.cpus} \\
        --output-file ${prefix}.profile.tsv

    ### Run pilea profile on deacon-filtered reads
    mkdir -p pilea_out
    ${pilea_link_r1}
    ${pilea_link_r2}
    pilea profile \\
        ${pilea_reads} \\
        -d ${pilea_db} \\
        -o pilea_out \\
        -t ${task.cpus}
    mv pilea_out/output.tsv ${prefix}.output.tsv
    rm -rf pilea_out ${prefix}.kmc ${pilea_cleanup}

    ### Extract contained viruses
    csvtk \\
        filter2 \\
        ${prefix}.profile.tsv \\
        --num-cpus ${task.cpus} \\
        --tabs \\
        --filter '( \$Genome_file == "genomes/uhvdb.species_reps.fna.gz" )' \\
        | csvtk cut --tabs -f Contig_name --out-delimiter '\t' \\
        --out-file ${prefix}.contained_viruses.tsv

    ### Align and compute gene coverage when contained viruses are present
    if [ -s ${prefix}.contained_viruses.tsv ]; then
        seqkit \\
            grep \\
            ${species_reps_fna_gz} \\
            --pattern-file ${prefix}.contained_viruses.tsv \\
            --out-file ${prefix}.contained_viruses.fna.gz

        TMPDIR=.

        coverm contig \\
            --threads ${task.cpus} \\
            ${coverm_reads} \\
            --reference ${prefix}.contained_viruses.fna.gz \\
            --bam-file-cache-directory _bam_cache/ \\
            --mapper strobealign \\
            --methods trimmed_mean mean variance covered_bases length \\
            --output-file ${prefix}.depth.tsv

        gzip ${prefix}.depth.tsv
        bam=\$(ls _bam_cache/*.bam | head -n 1)

        python -c "import pysam; pysam.index('\${bam}')"

        uhvdb_genecoverage.py \\
            --bam \${bam} \\
            --annotations ${annotations} \\
            --threads ${task.cpus} \\
            --output ${prefix}.gene_coverage.tsv

        python -c "import gzip, shutil, os; src='${prefix}.gene_coverage.tsv'; shutil.copyfileobj(open(src,'rb'), gzip.open(src+'.gz','wb')); os.unlink(src)"

        rm -rf _bam_cache/ \${bam} \${bam}.bai ${prefix}.contained_viruses.fna.gz
    fi

    ### Cleanup to save disk
    rm -rf ${prefix}*deacon*.fastq.gz *.fastp.html *.fastp.json ${prefix}.contained_viruses.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.profile.tsv
    touch ${prefix}.output.tsv
    echo "" | gzip > ${prefix}.depth.tsv.gz
    python -c "import gzip; gzip.open('${prefix}.gene_coverage.tsv.gz', 'wt').write('')"
    """
}
