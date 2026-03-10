process UHVDB_TAXONOMY {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/20/20f2108184abf393bb57a8dab1ab4afb4e3c51a06c0c72e0f7f17f3e5ad25a0c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-dbcb4ee0f0334b05_1?_gl=1*1lf6zxd*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.output_dir}/${params.new_release_id}/uhvdb/taxonomy/uhvdb_taxonomy"

    input:
    tuple val(meta), path(normscore_tsv_gz)
    tuple val(meta2), path(classify_tsv_gz)
    tuple val(meta3), path(vmr_url)

    output:
    tuple val(meta), path("${meta.id}.taxonomy.tsv.gz")     , emit: tsv_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Combine taxonomy data
    uhvdb_taxonomy.py \\
        --normscore_tsv ${normscore_tsv_gz} \\
        --classify_tsv ${classify_tsv_gz} \\
        --vmr_url ${vmr_url} \\
        --output ${meta.id}.taxonomy.tsv

    ### Compress
    gzip ${meta.id}.taxonomy.tsv
    """
}
