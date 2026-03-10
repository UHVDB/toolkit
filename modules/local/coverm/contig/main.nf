process COVERM_CONTIG {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/22/2206e95daa31b0ebb953967a6addc7c21eb740f3ea5da4d3651c0161d99195a5/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-9c711c96ce59e29a_1?_gl=1*mvshhs*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(spring), path(tsv_gz)
    tuple val(meta2), path(fna)

    output:
    tuple val(meta), path("${meta.id}.coverm.tsv.gz")   , emit: tsv_gz
    tuple val(meta), path("bam/*.bam")                  , emit: bam

    script:
    def spring_out  = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_R1.fastq.gz ${meta.id}_R2.fastq.gz"
    def coverm_reads = meta.single_end ? "--single ${meta.id}.fastq.gz" : "-1 ${meta.id}_R1.fastq.gz -2 ${meta.id}_R2.fastq.gz"
    """
    # decompress spring archive
    spring \\
        --decompress \\
        --input-file ${spring} \\
        --output-file ${spring_out} \\
        --gzipped_fastq \\
        --num-threads ${task.cpus}

    # extract contained genomes from sylph profile
    csvtk mutate \\
        ${tsv_gz} \\
        --tabs \\
        --fields Contig_name \\
        --name contig_id \\
        -p "^(.+?)\\s" | \\
    csvtk cut \\
        --tabs \\
        --fields contig_id \\
        > ${meta.id}.contained_genomes.txt

    seqkit grep \\
        ${fna} \\
        --pattern-file ${meta.id}.contained_genomes.txt \\
        -o ${meta.id}.contained_genomes.fna.gz

    # run coverm contig
    if [ \$(zgrep -c "^>" ${meta.id}.contained_genomes.fna.gz) == 0 ]; then
        echo "No contained genomes found for sample ${meta.id}"

        touch ${meta.id}.coverm.tsv
        mkdir -p ${meta.id}.bam
        touch ${meta.id}.bam/empty.bam
    else
        coverm contig \\
        ${coverm_reads} \\
        --reference ${meta.id}.contained_genomes.fna.gz \\
        --mapper strobealign \\
        --methods trimmed_mean mean variance covered_bases length \\
        --output-file ${meta.id}.coverm.tsv \\
        --threads ${task.cpus} \\
        --bam-file-cache-directory bam
    fi

    gzip ${meta.id}.coverm.tsv
    """
}
