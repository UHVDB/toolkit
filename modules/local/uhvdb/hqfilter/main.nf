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