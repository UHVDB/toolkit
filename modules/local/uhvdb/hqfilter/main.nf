process UHVDB_HQFILTER {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ff/ff2c7e6a1d237f65056929cb69cf5301742780ff22a7f79d5b763c72874b8de6/data':
        'community.wave.seqera.io/library/biopython_polars:1c1d88559d24ac35' }"

    input:
    tuple val(meta), path(fasta), path(classify), path(completeness)

    output:
    tuple val(meta), path("*.uhvdb_hq.fna.gz")    , emit: fna_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('biopython'), eval('python -c "import Bio; print(Bio.__version__)"'), topic: versions, emit: versions_biopython
    tuple val("${task.process}"), val('uhvdb_hqfilter'), eval('uhvdb_hqfilter.py --version'), topic: versions, emit: versions_uhvdb_hqfilter

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Extract HQ viruses
    uhvdb_hqfilter.py \\
        --input_completeness ${completeness} \\
        --classify_tsv ${classify} \\
        --fasta ${fasta} \\
        --output ${prefix}.uhvdb_hq.fna

    ### Compress
    gzip ${prefix}.uhvdb_hq.fna
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Touch empty output files
    echo "" | gzip > ${prefix}.uhvdb_hq.fna.gz
    """
}