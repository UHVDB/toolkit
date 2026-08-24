process INTERPROSCAN_DOWNLOAD {
    tag "IPS 5.76-107.0"
    label 'process_long'
    storeDir "${params.dbdir}/interproscan"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/5516280a314e0fb2f9bdbdeceeb42bb47732ac5451ec817b56df8f0931db1b8e/data' :
        'community.wave.seqera.io/library/python_wget:latest' }"

    output:
    path("interproscan-5.76-107.0"), emit: db

    script:
    """
    ### Download
    wget https://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.76-107.0/interproscan-5.76-107.0-64-bit.tar.gz
    wget https://ftp.ebi.ac.uk/pub/software/unix/iprscan/5/5.76-107.0/interproscan-5.76-107.0-64-bit.tar.gz.md5

    ### Check md5sum
    md5sum -c interproscan-5.76-107.0-64-bit.tar.gz.md5

    ### Extract
    tar -pxvzf interproscan-5.76-107.0-64-bit.tar.gz
    rm -rf interproscan-5.76-107.0-64-bit.tar.gz

    ### Setup
    cd interproscan-5.76-107.0
    python3 setup.py -f interproscan.properties
    """

    stub:
    """
    mkdir -p interproscan-5.76-107.0/data
    touch interproscan-5.76-107.0/interproscan.sh
    """
}
