process UHVDB_HQFILTER {
    tag "$meta.id"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(fasta), path(tsv_gz)
    tuple val(meta2), path(classify_tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.hq_viruses.fna.gz")   , emit: fna_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Extract HQ viruses
    uhvdb_hqfilter.py \\
        --input_completeness ${tsv_gz} \\
        --classify_tsv ${classify_tsv_gz} \\
        --output ${meta.id}.hq_viruses.txt

    seqkit grep \\
        ${fasta} \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}.hq_viruses.txt \\
        --out-file ${meta.id}.hq_viruses.fna.gz

    ### Cleanup
    rm ${meta.id}.hq_viruses.txt
    """
}
