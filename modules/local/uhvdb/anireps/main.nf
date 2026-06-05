process UHVDB_ANIREPS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c294e0026b39f8f08f779c442c998417549255edc252e45132701fd9f36a06cf/data':
        'community.wave.seqera.io/library/seqkit_polars:d8092df540cb603a' }"

    input:
    tuple val(meta) , path(new_fna_gz, stageAs: "new.fna.gz")
    path(old_fna_gz, stageAs: "old.fna.gz")
    tuple val(meta3), path(classify_tsv_gz)
    tuple val(meta4), path(completeness_tsv_gz)
    tuple val(meta5), path(mcl_gz)
    path(uhvdb_metadata_tsv_gz)

    output:
    tuple val(meta), path("*.info.tsv.gz")     , emit: tsv_gz
    tuple val(meta), path("*.new_reps.fna.gz") , emit: new_fna_gz
    tuple val(meta), path("*.old_reps.fna.gz") , emit: old_fna_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('uhvdb_anireps'), eval('uhvdb_anireps.py --version'), topic: versions, emit: versions_uhvdb_anireps
 
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    """
    ### Extract all IDs
    zgrep "^>" ${new_fna_gz} | sed 's/>//g; s/\s.*//' > ${prefix}.all_ids.txt
    zgrep "^>" ${old_fna_gz} | sed 's/>//g; s/\s.*//' >> ${prefix}.all_ids.txt

    ### Identify ANI reps
    uhvdb_anireps.py \\
        --mcl ${mcl_gz} \\
        --unique ${prefix}.all_ids.txt \\
        --tsv ${classify_tsv_gz} \\
        --completeness ${completeness_tsv_gz} \\
        --uhvdb_metadata ${uhvdb_metadata_tsv_gz} \\
        --output_reps ${prefix}.reps.tsv \\
        --output_new_reps ${prefix}.new_reps.tsv \\
        --cluster_info ${prefix}.info.tsv \\
        ${args}

    ### Extract rep sequences
    seqkit grep \\
        ${old_fna_gz} \\
        --pattern-file ${prefix}.reps.tsv \\
        --threads ${task.cpus} \\
        --out-file ${prefix}.old_reps.fna.gz

    seqkit grep \\
        ${old_fna_gz} ${new_fna_gz} \\
        --pattern-file ${prefix}.new_reps.tsv \\
        --threads ${task.cpus} \\
        --out-file ${prefix}.new_reps.fna.gz
        
    ### Compress
    gzip ${prefix}.info.tsv

    ### Cleanup
    rm ${prefix}.reps.tsv
    rm ${prefix}.new_reps.tsv
    rm ${prefix}.all_ids.txt
    """
}
