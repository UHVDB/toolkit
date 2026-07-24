process UHVDB_RENAME {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ff/ff2c7e6a1d237f65056929cb69cf5301742780ff22a7f79d5b763c72874b8de6/data':
        'community.wave.seqera.io/library/biopython_polars:1c1d88559d24ac35' }"
    
    input:
    tuple val(meta) , path(tsv_gz)
    tuple val(meta2) , path(map_tsv_gz)

    output:
    tuple val(meta) , path("*.tsv.gz") , emit: tsv_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('biopython'), eval('python -c "import Bio; print(Bio.__version__)"'), topic: versions, emit: versions_biopython
    tuple val("${task.process}"), val('uhvdb_rename'), eval('uhvdb_rename.py --version'), topic: versions, emit: versions_uhvdb_rename

    script:
    def prefix = task.ext.prefix ?: "${meta.id}.rename"
    """
    ### Replace seq_name in classify.tsv.gz 
    uhvdb_rename.py \\
        --classify_tsv ${tsv_gz} \\
        --id_mapping_tsv ${map_tsv_gz} \\
        --output_tsv ${prefix}.tsv
    
    ### Compress
    gzip ${prefix}.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.rename"
    """
    echo "" | gzip > ${prefix}.tsv.gz
    """
}
