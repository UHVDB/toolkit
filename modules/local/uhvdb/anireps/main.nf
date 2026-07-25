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
    val cluster_level

    output:
    tuple val(meta), path("*.info.tsv.gz")     , emit: tsv_gz
    tuple val(meta), path("*.new_reps.fna.gz") , emit: new_fna_gz
    tuple val(meta), path("*.old_reps.fna.gz") , emit: old_fna_gz
 
    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Identify ANI reps
    ### Old sequence IDs come from metadata inside uhvdb_anireps.py
    ### (avoids a full decompress of old.fna.gz just for headers)
    uhvdb_anireps.py \\
        --mcl ${mcl_gz} \\
        --new_fna ${new_fna_gz} \\
        --tsv ${classify_tsv_gz} \\
        --completeness ${completeness_tsv_gz} \\
        --uhvdb_metadata ${uhvdb_metadata_tsv_gz} \\
        --output_reps ${prefix}.reps.tsv \\
        --output_new_reps ${prefix}.new_reps.tsv \\
        --cluster_info ${prefix}.info.tsv \\
        --cluster_level ${cluster_level}

    ### Extract rep sequences from old.fna.gz in a single pass, then split.
    ### reps.tsv = previous reps that remain; new_reps.tsv = not in previous rep set
    cat ${prefix}.reps.tsv ${prefix}.new_reps.tsv | sort -u > ${prefix}.all_rep_ids.tsv

    if [ -s ${prefix}.all_rep_ids.tsv ]; then
        seqkit grep \\
            ${old_fna_gz} \\
            --pattern-file ${prefix}.all_rep_ids.tsv \\
            --threads ${task.cpus} \\
            --out-file ${prefix}.from_old.fna.gz
    else
        echo -n | gzip > ${prefix}.from_old.fna.gz
    fi

    if [ -s ${prefix}.reps.tsv ]; then
        seqkit grep \\
            ${prefix}.from_old.fna.gz \\
            --pattern-file ${prefix}.reps.tsv \\
            --threads ${task.cpus} \\
            --out-file ${prefix}.old_reps.fna.gz \\
            || echo -n | gzip > ${prefix}.old_reps.fna.gz
    else
        echo -n | gzip > ${prefix}.old_reps.fna.gz
    fi

    if [ -s ${prefix}.new_reps.tsv ]; then
        # Split sources to avoid a second full scan of old.fna.gz.
        # Either source may have zero hits; keep empty gzip members so
        # concatenated order still matches seqkit grep old then new.
        seqkit grep \\
            ${prefix}.from_old.fna.gz \\
            --pattern-file ${prefix}.new_reps.tsv \\
            --threads ${task.cpus} \\
            --out-file ${prefix}.new_from_old.fna.gz \\
            || echo -n | gzip > ${prefix}.new_from_old.fna.gz
        seqkit grep \\
            ${new_fna_gz} \\
            --pattern-file ${prefix}.new_reps.tsv \\
            --threads ${task.cpus} \\
            --out-file ${prefix}.new_from_new.fna.gz \\
            || echo -n | gzip > ${prefix}.new_from_new.fna.gz
        cat ${prefix}.new_from_old.fna.gz ${prefix}.new_from_new.fna.gz > ${prefix}.new_reps.fna.gz
    else
        echo -n | gzip > ${prefix}.new_reps.fna.gz
    fi

    ### Compress cluster info (plain TSV from uhvdb_anireps.py)
    gzip ${prefix}.info.tsv

    ### Cleanup
    rm -f \\
        ${prefix}.reps.tsv \\
        ${prefix}.new_reps.tsv \\
        ${prefix}.all_rep_ids.tsv \\
        ${prefix}.from_old.fna.gz \\
        ${prefix}.new_from_old.fna.gz \\
        ${prefix}.new_from_new.fna.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.info.tsv.gz
    echo "" | gzip > ${prefix}.new_reps.fna.gz
    echo "" | gzip > ${prefix}.old_reps.fna.gz
    """
}
