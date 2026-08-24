process UHVDB_REFERENCEACTIVITY {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    // Container URI should match environment.yml (Wave image to be added)
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5e/5e312b2c6046904fd61ac87c80908e3e648ace25d48ed35b2e862bdf33d1eee3/data':
        'community.wave.seqera.io/library/numpy_pandas_polars_pyarrow_pruned:bdf89707e543c55b' }"

    input:
    tuple val(meta), path(sylph_tax), path(coverm_tsv_gz), path(profile_tsv), path(gene_coverage_tsv_gz)
    path(uhvdb_metadata_tsv_gz)
    path(model_path)
    path(metadata_path)

    output:
    tuple val(meta), path("${meta.id}_reference_activity.tsv.gz"), emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def group  = meta.group ?: meta.id
    """
    uhvdb_referenceactivity.py \\
        --uhvdb_metadata ${uhvdb_metadata_tsv_gz} \\
        --coverm ${coverm_tsv_gz} \\
        --sylph_tax ${sylph_tax} \\
        --profile ${profile_tsv} \\
        --gene_coverage ${gene_coverage_tsv_gz} \\
        --model_path ${model_path} \\
        --metadata_path ${metadata_path} \\
        --sample_id '${meta.id}' \\
        --group '${group}' \\
        --output ${prefix}_reference_activity.tsv

    python -c "import gzip, shutil, os; src='${prefix}_reference_activity.tsv'; shutil.copyfileobj(open(src,'rb'), gzip.open(src+'.gz','wb')); os.unlink(src)"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python -c "import gzip; gzip.open('${prefix}_reference_activity.tsv.gz', 'wt').write('sample_id\\tgroup\\tspecies_cluster_id\\tuhvdb_id\\tictv_class\\tpredicted_inactive_probability\\tpredicted_uninducible\\tinactive_confidence_tier\\n')"
    """
}
