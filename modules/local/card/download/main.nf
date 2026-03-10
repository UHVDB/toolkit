process CARD_DOWNLOAD {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-b7c8dc0d49f17b63_1?_gl=1*1sesm3q*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.db_dir}/card/4.0.1"
    tag "CARD v4.0.1"
    
    output:
    path("CARD.dmnd")       , emit: dmnd
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    ### Download CARD proteins
    wget https://card.mcmaster.ca/download/0/broadstreet-v4.0.1.tar.bz2

    ### Create DIAMOND database
    tar -xvf broadstreet-v4.0.1.tar.bz2

    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in protein_fasta_protein_homolog_model.fasta \\
        -d CARD

    ### Cleanup
    rm -rf broadstreet-v4.0.1.tar.bz2 broadstreet-v4.0.1
    """
}
