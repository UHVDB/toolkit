process UHVDB_COMPLETEGENOMES {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta), path(tsv_gz), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.uhvdb_complete_genomes.fna.gz")   , emit: fna_gz
    path ".command.log"                                                 , emit: log
    path ".command.sh"                                                  , emit: script

    script:
    """
    ### Extract complete genomes
    uhvdb_complete_genomes.py \\
        --classify_fna ${fasta} \\
        --classify_tsv ${tsv_gz} \\
        --output ${meta.id}.uhvdb_complete_genomes.tsv

    seqkit grep \\
        ${fasta} \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}.uhvdb_complete_genomes.tsv \\
        --out-file ${meta.id}.uhvdb_complete_genomes.fna.gz

    ### Cleanup
    rm ${meta.id}.uhvdb_complete_genomes.tsv
    """
}
