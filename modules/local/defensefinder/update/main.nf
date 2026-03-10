process DEFENSEFINDER_UPDATE {
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/9f/9f526ee1d099eefa2eb73c0d75cf9996d24ba27d9126f0d029ce8e90cef650cc/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-7badfd5aee700fa8_1?_gl=1*1kyxbts*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.
    storeDir "${params.db_dir}/defensefinder/2.0.2"
    tag "defensefinder v2.0.1; models v2.0.2"

    output:
    path("defensefinder_db/")   , emit: db
    path(".command.log")        , emit: log
    path(".command.sh")         , emit: script

    script:
    """
    ### Download
    defense-finder update --models-dir defensefinder_db

    ### Fix download (compatible)
    cd defensefinder_db
    rm -rf CasFinder
    wget https://github.com/macsy-models/CasFinder/archive/refs/tags/3.1.0.tar.gz
    tar -xvf 3.1.0.tar.gz
    mv CasFinder-3.1.0/ CasFinder/
    rm -rf 3.1.0.tar.gz
    """
}
