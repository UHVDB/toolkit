process VIRALVERIFY_VIRALVERIFY {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/47/472ca345aeaaaae70034c8bc04e1d62b226e188ec9edc16b7dfd43f83a25ed8e/data'
        : 'community.wave.seqera.io/library/viralverify:1.1--3527fad4ef7ee6f4'}"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path ("*_result_table.csv.gz")  , emit: csv_gz
    tuple val(meta), path ("*_domtblout.gz")         , emit: domtblout_gz

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def is_compressed  = fasta.getExtension() == "gz" ? true : false
    def fasta_name     = is_compressed ? fasta.getBaseName().replace(".gz", "") : fasta
    """
    ### Uncompres
    if [ "${is_compressed}" == "true" ]; then
        gzip -c -d ${fasta} > ${fasta_name}
    fi

    ### Run ViralVerify
    viralverify \\
        -f ${fasta_name} \\
        --hmm ${db} \\
        -o ${prefix}_viralverify \\
        -t ${task.cpus} \\
        ${args}

    ### Compress
    gzip -c ${prefix}_viralverify/${file(fasta_name).getBaseName()}_result_table.csv > ${prefix}_result_table.csv.gz
    gzip -c ${prefix}_viralverify/${file(fasta_name).getBaseName()}_domtblout > ${prefix}_domtblout.gz

    ### Cleanup
    rm -rf ${prefix}_viralverify
    rm -f ${fasta_name}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Touch empty output file
    echo "" | gzip > ${prefix}_result_table.csv.gz
    echo "" | gzip > ${prefix}_domtblout.gz
    """
}
