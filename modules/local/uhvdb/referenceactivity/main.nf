process UHVDB_REFERENCEACTIVITY {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/04/040ad58d7a1cf2edfcaeedec400586068287ec5a76ffd3b80e452582e45e611d/data':
        'community.wave.seqera.io/library/numpy_pandas_polars_pyarrow_pruned:e3ef6ec6a95d9c84' }"
    
    input:
    tuple val(meta), path(sylph_tax_tsv_gz), path(coverm_tsv_gz)
    path(uhvdb_metadata_tsv_gz)
    path(model_path)
    path(metadata_path)

    output:
    tuple val(meta), path("${meta.id}_reference_activity.tsv.gz")   , emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Calculate reference activity tier
    uhvdb_referenceactivity.py \\
        --uhvdb_metadata ${uhvdb_metadata_tsv_gz} \\
        --coverm ${coverm_tsv_gz} \\
        --sylph_tax ${sylph_tax_tsv_gz} \\
        --model_path ${model_path} \\
        --metadata_path ${metadata_path} \\
        --output ${prefix}_reference_activity.tsv \\
        --sample_id ${meta.id} \\
        --group ${meta.group}

    ### Compress
    gzip ${prefix}_reference_activity.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}_reference_activity.tsv.gz
    """
}
