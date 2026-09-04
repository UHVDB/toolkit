process UHVDB_ASSEMBLYACTIVITY {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/5e/5e312b2c6046904fd61ac87c80908e3e648ace25d48ed35b2e862bdf33d1eee3/data':
        'community.wave.seqera.io/library/numpy_pandas_polars_pyarrow_pruned:bdf89707e543c55b' }"

    input:
    tuple val(meta), path(sylphmpa), path(classify_tsv), path(mvirs_fasta), path(propagate_tsv), path(gani_tsv)
    path(uhvdb_metadata_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.assemblyactivity.sylphmpa"), emit: sylphmpa

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    uhvdb_assemblyactivity.py \\
        --sylph_tax ${sylphmpa} \\
        --classify ${classify_tsv} \\
        --mvirs_fasta ${mvirs_fasta} \\
        --propagate ${propagate_tsv} \\
        --gani ${gani_tsv} \\
        --uhvdb_metadata ${uhvdb_metadata_tsv_gz} \\
        --output ${prefix}.assemblyactivity.sylphmpa
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python -c "open('${prefix}.assemblyactivity.sylphmpa', 'w').write('#SampleID\\tstub\\nclade_name\\trelative_abundance\\tsequence_abundance\\tani\\tcoverage\\tvirus_host\\tvirus_lifestyle\\tpth_ratio\\tptr\\tuninducible_probability\\tuninducible_tier\\ttr\\tmvirs\\tpropagate\\n')"
    """
}
