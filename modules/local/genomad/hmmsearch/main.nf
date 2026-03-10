process GENOMAD_HMMSEARCH {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b9/b9daea85c023fb5960af838221201816f7ba53c5d4b7ff664ee19d371c14ceaa/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ff059d86270f7a0e_1?_gl=1*19cdyj*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , path(fna_gz)
    path(hmm)
    path(tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.uncertain2confident.fna.gz")  , emit: fna_gz
    tuple val(meta), path("${meta.id}.hmmsearch.tsv.gz")            , emit: tsv_gz
    path(".command.log")                                            , emit: log
    path(".command.sh")                                             , emit: script

    script:
    """
    ### Predict genes
    pyrodigal-gv \\
        -i ${fna_gz} \\
        -a ${meta.id}.pyrodigalgv.faa \\
        --jobs ${task.cpus} &> /dev/null

    ### Run hmmsearch
    hmmsearch --noali \\
        -o /dev/null \\
        -E 1e-5 \\
        --tblout ${meta.id}_v_genomad_hallmarks.tbl \\
        --cpu ${task.cpus} \\
        ${hmm} \\
        ${meta.id}.pyrodigalgv.faa \\
        2> hmmsearch.log

    ### Identify confident viruses
    uhvdb_uncertain2confident.py \\
        --hmmsearch_tbl ${meta.id}_v_genomad_hallmarks.tbl \\
        --genomad_tsv ${tsv_gz} \\
        --output ${meta.id}.hmmsearch.tsv \\
        --ids ${meta.id}.uncertain2confident.tsv
    
    gzip ${meta.id}.hmmsearch.tsv

    ### Extract confident viruses
    seqkit grep \\
        ${fna_gz} \\
        --pattern-file ${meta.id}.uncertain2confident.tsv \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}.uncertain2confident.fna.gz

    ### Cleanup
    rm -rf ${meta.id}.pyrodigalgv.faa ${meta.id}.uncertain2confident.tsv ${meta.id}_v_genomad_hallmarks.tbl
    """
}
