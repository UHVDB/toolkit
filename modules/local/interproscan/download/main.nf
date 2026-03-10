process INTERPROSCAN_DOWNLOAD {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/55/5516280a314e0fb2f9bdbdeceeb42bb47732ac5451ec817b56df8f0931db1b8e/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-68e8eace36956f36_1?_gl=1*1xpav14*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..
    storeDir "${params.db_dir}/interproscan"
    tag "IPS 5.76-107.0"
    

    output:
    path("interproscan-5.76-107.0") , emit: db
    path(".command.log")            , emit: log
    path(".command.sh")             , emit: script

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
}
