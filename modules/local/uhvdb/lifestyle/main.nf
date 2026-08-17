process UHVDB_LIFESTYLE {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data' :
        'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071' }"

    input:
    tuple val(meta), path(bacphlip_tsv_gz)
    tuple val(meta2), path(classify_tsv_gz)
    tuple val(meta3), path(pharokka_tsv_gz)
    tuple val(meta4), path(phold_tsv_gz)
    tuple val(meta5), path(empathi_csv_gz)
    tuple val(meta6), path(protein2hash_tsv_gz)
    path(uhvdb_metadata_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}_lifestyle.tsv.gz"), emit: tsv_gz

    script:
    def uhvdb_metadata = uhvdb_metadata_tsv_gz.size() > 0 ? "--uhvdb_metadata ${uhvdb_metadata_tsv_gz}" : ""
    """
    ### Combine lifestyle data
    uhvdb_lifestyle.py \\
        --bacphlip_tsv ${bacphlip_tsv_gz} \\
        --classify_tsv ${classify_tsv_gz} \\
        --pharokka_tsv ${pharokka_tsv_gz} \\
        --phold_tsv ${phold_tsv_gz} \\
        --empathi_csv ${empathi_csv_gz} \\
        --protein2hash_tsv ${protein2hash_tsv_gz} \\
        ${uhvdb_metadata} \\
        --output ${meta.id}_lifestyle.tsv

    ### Compress
    gzip ${meta.id}_lifestyle.tsv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}_lifestyle.tsv.gz
    """
}
