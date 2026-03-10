process DEFENSEFINDER_RUN {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/9f/9f526ee1d099eefa2eb73c0d75cf9996d24ba27d9126f0d029ce8e90cef650cc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-7badfd5aee700fa8_1?_gl=1*1kyxbts*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.

    input:
    tuple val(meta) , path(faa)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.defense_finder_systems.tsv.gz")   , emit: systems_tsv_gz
    tuple val(meta), path("${meta.id}.defense_finder_genes.tsv.gz")     , emit: genes_tsv_gz
    tuple val(meta), path("${meta.id}.defense_finder_hmm.tsv.gz")       , emit: hmm_tsv_gz
    path(".command.log")                                                , emit: log
    path(".command.sh")                                                 , emit: script

    script:
    """
    ### Run defense-finder
    defense-finder run \\
        ${faa} \\
        -o ${meta.id} \\
        --antidefensefinder \\
        --models-dir ${db} \\
    
    mv ${meta.id}/*_defense_finder_systems.tsv ${meta.id}.defense_finder_systems.tsv
    mv ${meta.id}/*_defense_finder_genes.tsv ${meta.id}.defense_finder_genes.tsv
    mv ${meta.id}/*_defense_finder_hmmer.tsv ${meta.id}.defense_finder_hmm.tsv

    ### Compress
    gzip ./*.tsv

    ### Cleanup
    rm -rf ${meta.id}/ *.idx
    """
}
