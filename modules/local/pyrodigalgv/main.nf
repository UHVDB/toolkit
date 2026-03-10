process PYRODIGALGV {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f0/f0fa5a54c3d6d0e86498282a8b90164121480936d8edfa53240758a44307048e/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-fe984e37c9f9a62e_1?_gl=1*n455cd*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(fna)

    output:
    tuple val(meta), path("${meta.id}.pyrodigalgv.tsv.gz")  , emit: tsv_gz
    tuple val(meta), path("${meta.id}.pyrodigalgv.fna.gz")  , emit: fna_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Run pyrodigal-gv
    pyrodigal-gv \\
        -i ${fna} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        -d ${meta.id}.pyrodigalgv.fna \\
        -c \\
        --jobs ${task.cpus} \\
        >/dev/null 2>&1

    ### Convert to TSV
    seqkit fx2tab \\
        ${meta.id}.pyrodigalgv.faa \\
        --only-id --no-qual \\
        --seq-hash \\
        > ${meta.id}.pyrodigalgv.tsv

    ### Compress
    pigz -p ${task.cpus} ${meta.id}.pyrodigalgv.tsv ${meta.id}.pyrodigalgv.fna

    ### Cleanup
    rm ${meta.id}.pyrodigalgv.faa 
    """
}
