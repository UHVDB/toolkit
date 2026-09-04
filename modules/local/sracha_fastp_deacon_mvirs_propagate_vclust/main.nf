include { mvirsPropagateVclust } from '../fastp_deacon_mvirs_propagate_vclust/main'

process SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST {
    tag "${meta.id}"
    label 'process_super_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b35e98507506ad91f67a5cb44089d7b14d7b794291b99c2cc0e866c72d29355/data' :
        'community.wave.seqera.io/library/sracha_fastp_deacon_mvirs_pruned:45403beba8693cd2' }"

    input:
    tuple val(meta), val(acc), path(assembly_fna), path(classify_tsv), path(confident_fna)
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
    ### Download with sracha
    sracha get \\
        ${acc} \\
        --format sralite \\
        --threads ${task.cpus} \\
        --output-dir ${acc}/

    ### Prepare fastp and deacon input and output files
    if ls ${acc}/${acc}_2.fastq.gz 1> /dev/null 2>&1; then
        mv ${acc}/*_1.fastq.gz ${acc}/${acc}_R1.fastq.gz
        mv ${acc}/*_2.fastq.gz ${acc}/${acc}_R2.fastq.gz
        fastp_reads_in="--in1 ${acc}/${acc}_R1.fastq.gz --in2 ${acc}/${acc}_R2.fastq.gz"
        fastp_reads_out="--out1 ${acc}_R1.fastp.fastq.gz --out2 ${acc}_R2.fastp.fastq.gz"
        deacon_reads_in="${acc}_R1.fastp.fastq.gz ${acc}_R2.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}_R1.deacon.fastq.gz --output2 ${acc}_R2.deacon.fastq.gz"
        mvirs_reads="-f ${acc}_R1.deacon.fastq.gz -r ${acc}_R2.deacon.fastq.gz"
        first_fastq="${acc}_R1.deacon.fastq.gz"
        is_paired=1
    else
        if ls ${acc}/*_1.fastq.gz 1> /dev/null 2>&1; then
            mv ${acc}/*_1.fastq.gz ${acc}/${acc}.fastq.gz
        elif [ ! -f ${acc}/${acc}.fastq.gz ]; then
            echo "ERROR: no FASTQ found for ${acc} after sracha get" >&2
            ls -la ${acc}/ >&2 || true
            exit 1
        fi
        fastp_reads_in="--in1 ${acc}/${acc}.fastq.gz"
        fastp_reads_out="--out1 ${acc}.fastp.fastq.gz"
        deacon_reads_in="${acc}.fastp.fastq.gz"
        deacon_reads_out="--output ${acc}.deacon.fastq.gz"
        mvirs_reads="-r ${acc}.deacon.fastq.gz"
        first_fastq="${acc}.deacon.fastq.gz"
        is_paired=0
    fi

    ### Run fastp
    fastp \\
        \${fastp_reads_in} \\
        \${fastp_reads_out} \\
        --json ${prefix}.fastp.json \\
        --html ${prefix}.fastp.html \\
        --thread ${task.cpus} \\
        --detect_adapter_for_pe

    ### Run deacon
    deacon filter \\
        --deplete \\
        ${index} \\
        \${deacon_reads_in} \\
        \${deacon_reads_out} \\
        --threads ${task.cpus}

    rm -rf *.fastp.fastq.gz ${acc}/

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
