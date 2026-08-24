process CARD_DOWNLOAD {
    tag "CARD v4.0.1"
    label 'process_medium'
    storeDir "${params.dbdir}/card/4.0.1"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data' :
        'quay.io/biocontainers/diamond:2.1.11--h5ca1c30_0' }"

    output:
    path("CARD.dmnd"), emit: dmnd

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
    rm -rf broadstreet-v4.0.1.tar.bz2 protein_fasta_protein_homolog_model.fasta *.txt *.json *.tsv card.json 2>/dev/null || true
    """

    stub:
    """
    touch CARD.dmnd
    """
}
