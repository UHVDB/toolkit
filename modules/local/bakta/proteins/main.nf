process BAKTA_PROTEINS {
    tag "${meta.id}"
    label 'process_high_mem'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/55528c8c8b5d2d6116a45c2b84bf410dcf83af3aeffe01e17ff87a8a2989ee77/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ec47114f75cb3555_1?_gl=1*alkje3*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    time '24.h'

    input:
    tuple val(meta) , path(faa_gz)
    path(db)
    path(uniref50_virus_db)
    path(bakta_mod)

    output:
    tuple val(meta), path("${meta.id}.inference.tsv.gz")    , emit: tsv_gz
    tuple val(meta), path("${meta.id}.nohit.faa.gz")        , emit: faa_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Run bakta
    bash bakta_mod/bin/bakta_proteins \\
        ${faa_gz} \\
        --db ${db} \\
        --proteins ${uniref50_virus_db} \\
        --threads ${task.cpus} \\
        --prefix ${meta.id} \\
        --output ./ \\
        --force \\
        --verbose

    ### Identify proteins without hits
    extract_nohit_proteins.py \\
        --input_tsv ${meta.id}.inference.tsv \\
        --input_faa ${faa_gz} \\
        --name_column="Locus Tag" \\
        --output ${meta.id}.nohit.faa

    ### Compress
    gzip -f ${meta.id}.inference.tsv
    gzip -f ${meta.id}.faa
    gzip -f ${meta.id}.nohit.faa

    ### Cleanup
    # rm -rf ${meta.id}.hypotheticals.tsv ${meta.id}.json ${meta.id}.tsv
    """
}
