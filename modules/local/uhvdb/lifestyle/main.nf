process UHVDB_LIFESTYLE {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.output_dir}/${params.new_release_id}/uhvdb/lifestyle/uhvdb_lifestyle"

    input:
    tuple val(meta), path(bacphlip_tsv_gz)
    tuple val(meta2), path(classify_tsv_gz)
    tuple val(meta3), path(pharokka_tsv_gz)
    tuple val(meta4), path(phold_tsv_gz)
    tuple val(meta5), path(empathi_csv_gz)
    tuple val(meta6), path(protein2hash_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.lifestyle.tsv.gz")    , emit: tsv_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Combine lifestyle data
    uhvdb_lifestyle.py \\
        --bacphlip_tsv ${bacphlip_tsv_gz} \\
        --classify_tsv ${classify_tsv_gz} \\
        --pharokka_tsv ${pharokka_tsv_gz} \\
        --phold_tsv ${phold_tsv_gz} \\
        --empathi_csv ${empathi_csv_gz} \\
        --protein2hash_tsv ${protein2hash_tsv_gz} \\
        --output ${meta.id}.lifestyle.tsv

    ### Compress
    gzip ${meta.id}.lifestyle.tsv
    """
}
