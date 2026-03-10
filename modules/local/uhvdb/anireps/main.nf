process UHVDB_ANIREPS {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2e/2ef3ddfbf985e3fbe66d26b28c420d94a9e6055c07b54834129389fa6adf5321/data"
    storeDir "${params.output_dir}/${params.new_release_id}_outputs/anicluster/"

    input:
    tuple val(meta), path(ref_fna_gz, stageAs: "ref.fna.gz"), path(query_fna_gz), path(tsv_gz), path(completeness_tsv_gz), path(mcl_gz), path(uhvdb_metadata_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.ani_reps_info.tsv.gz"), emit: tsv_gz
    tuple val(meta), path("${meta.id}.ani_reps.fna.gz")     , emit: fna_gz
    // path ".command.log"                                     , emit: log
    // path ".command.sh"                                      , emit: script

    script:
    def use_ref = ref_fna_gz.size() > 0 ? "true" : "false"
    def uhvdb_metadata = uhvdb_metadata_tsv_gz.size() > 0 ? "--uhvdb_metadata ${uhvdb_metadata_tsv_gz}" : ""
    """
    ### Extract all IDs
    zgrep "^>" ${query_fna_gz} | sed 's/>//g; s/\s.*//' > ${meta.id}.all_ids.txt
    if [ ${use_ref} == "true" ]; then
        zgrep "^>" ${ref_fna_gz} | sed 's/>//g; s/\s.*//' >> ${meta.id}.all_ids.txt
    fi

    ### Identify ANI reps
    uhvdb_ani_reps.py \\
        --mcl ${mcl_gz} \\
        --unique ${meta.id}.all_ids.txt \\
        --tsv ${tsv_gz} \\
        --completeness ${completeness_tsv_gz} \\
        ${uhvdb_metadata} \\
        --output_reps ${meta.id}.ani_reps.tsv \\
        --cluster_info ${meta.id}.ani_reps_info.tsv

    ### Extract rep sequences
    if [ ${use_ref} == "true" ]; then
        fna_arg="${query_fna_gz} ${ref_fna_gz}"
    else
        fna_arg="${query_fna_gz}"
    fi
    seqkit grep \\
        \${fna_arg} \\
        --pattern-file ${meta.id}.ani_reps.tsv \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}.ani_reps.fna.gz

    ### Compress
    gzip ${meta.id}.ani_reps_info.tsv

    ### Cleanup
    rm ${meta.id}.ani_reps.tsv
    """
}
