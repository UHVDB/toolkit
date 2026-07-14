process UHVDB_UNIQUEHASH {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ff/ff2c7e6a1d237f65056929cb69cf5301742780ff22a7f79d5b763c72874b8de6/data':
        'community.wave.seqera.io/library/biopython_polars:1c1d88559d24ac35' }"
    
    input:
    tuple val(meta), path(new_seqhasher_tsv_gzs, stageAs: 'to_concatenate/*', arity: '1..*')
    path(uhvdb_metadata_tsv_gz)

    output:
    tuple val(meta), path("uhvdb_seqhasher.tsv.gz"), emit: tsv_gz
    tuple val(meta), path("uhvdb_id_map.tsv.gz"), emit: id_map_tsv_gz
    tuple val(meta), path("*.fna.gz"), emit: fna_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('biopython'), eval('python -c "import Bio; print(Bio.__version__)"'), topic: versions, emit: versions_biopython
    tuple val("${task.process}"), val('uhvdb_uniquehash'), eval('uhvdb_uniquehash.py --version'), topic: versions, emit: versions_uhvdb_uniquehash

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Concatenate TSVs
    while IFS= read -r -d \$'\\0' file; do
            cat \$file \\
                >> combined_seqhasher.tsv.gz
        done < <( find to_concatenate/ -mindepth 1 -print0 | sort -z )

    ### Run unique hash
    uhvdb_uniquehash.py \\
        --input_seqhash_tsv combined_seqhasher.tsv.gz \\
        --uhvdb_metadata_tsv ${uhvdb_metadata_tsv_gz} \\
        --output_tsv uhvdb_seqhasher.tsv \\
        --output_id_map_tsv uhvdb_id_map.tsv \\
        --output_fna ${prefix}.fna

    ### Compress
    gzip uhvdb_seqhasher.tsv uhvdb_id_map.tsv ${prefix}.fna

    ### Cleanup
    rm -rf combined_seqhasher.tsv.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > uhvdb_seqhasher.tsv.gz
    echo "" | gzip > uhvdb_id_map.tsv.gz
    echo "" | gzip > ${prefix}.fna.gz
    """
}
