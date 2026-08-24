process UHVDB_PROTEINHASH {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ff/ff2c7e6a1d237f65056929cb69cf5301742780ff22a7f79d5b763c72874b8de6/data':
        'community.wave.seqera.io/library/biopython_polars:1c1d88559d24ac35' }"

    input:
    tuple val(meta), path(tsv_gzs, stageAs: 'to_concatenate/*', arity: '1..*')
    path(uhvdb_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}_prothash.tsv.gz"), emit: tsv_gz
    tuple val(meta), path("new_proteins.faa.gz")       , emit: faa_gz

    script:
    def uhvdb_tsv_gz_input = uhvdb_tsv_gz ? "--input_uhvdb_prothash_tsv ${uhvdb_tsv_gz}" : "--input_uhvdb_prothash_tsv ''"
    """
    ### Concatenate TSVs
    while IFS= read -r -d \$'\\0' file; do
            cat \$file \\
                >> ${meta.id}.combined_prothash.tsv.gz
        done < <( find to_concatenate/ -mindepth 1 -print0 | sort -z )

    # 1. Identify new hashes that are not in the existing UHVDB (if provided)
    # 2. Write out new unique sequences in fasta format
    # 3. Write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    uhvdb_proteinhash.py \\
        --input_prothash_tsv ${meta.id}.combined_prothash.tsv.gz \\
        ${uhvdb_tsv_gz_input} \\
        --output_combined_prothash_tsv ${meta.id}_prothash.tsv \\
        --output_new_unique_fna new_proteins.faa

    ### Compress
    gzip ${meta.id}_prothash.tsv new_proteins.faa

    ### Cleanup
    rm -rf ${meta.id}.combined_prothash.tsv.gz
    """

    stub:
    """
    echo -e "protein_id\\thash" | gzip > ${meta.id}_prothash.tsv.gz
    echo "" | gzip > new_proteins.faa.gz
    """
}
