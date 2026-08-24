process ICTV_DOWNLOADER {
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b1/b12acc928f98718702bedce5b0517fa2b4638f83eb1b4d3ce7e402df3afd61f3/data':
        'community.wave.seqera.io/library/ictv-downloader:65be71184be13039' }"

    output:
    path("*.fna.gz")                      , emit: fna_gz

    script:
    """
    ### Download ICTV genomic nucleotide sequences from the current VMR
    ictv_downloader.py \\
        --type genomic \\
        -o ictv_genomes.fna

    ### Compress
    gzip ictv_genomes.fna
    """

    stub:
    """
    echo "" | gzip > ictv_genomes.fna.gz
    """
}
