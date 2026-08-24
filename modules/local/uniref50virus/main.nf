process UNIREF50VIRUS {
    tag "UniRef50 viruses v2026_03"
    label 'process_medium'
    storeDir "${params.dbdir}/uniref50virus/2026_03"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b42aefebb4f496d83f832ea6ce13b79cd893b62d2b80dcd9bc5c9784b0e9ff0/data' :
        'community.wave.seqera.io/library/python_requests:latest' }"

    output:
    path("uniref50_virus.faa.gz"), emit: faa_gz

    script:
    """
    # download uniref50 representatives with virus taxonomy
    get_uniref50_virus.py

    # gzip fasta
    gzip uniref50_virus.faa
    """

    stub:
    """
    echo "" | gzip > uniref50_virus.faa.gz
    """
}
