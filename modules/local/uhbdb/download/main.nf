process UHBDB_DOWNLOAD {
    label 'process_single'
    tag "UHBDB 1.0"
    storeDir "${params.dbdir}/uhbdb/1.0"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("uhbdb"), emit: uhbdb_dir

    script:
    """
    ### Download database
    wget https://s3.kopah.uw.edu/uhbdb/2026-03-05.tar -O uhbdb_2026-03-05.tar
    wget https://s3.kopah.uw.edu/uhbdb/2026-03-11.tar -O uhbdb_2026-03-11.tar

    ### Extract database
    mkdir -p uhbdb
    tar -xf uhbdb_2026-03-05.tar -C uhbdb
    tar -xf uhbdb_2026-03-11.tar -C uhbdb

    ### Cleanup
    rm uhbdb_2026-03-05.tar uhbdb_2026-03-11.tar
    """

    stub:
    """
    mkdir -p uhbdb/test/Absicoccus uhbdb/test/Abiotrophia
    touch uhbdb/test/Absicoccus/Absicoccus.agc
    touch uhbdb/test/Abiotrophia/Abiotrophia.agc
    echo -e "genome_id\\ttaxonomy" | gzip > uhbdb/test/Absicoccus/Absicoccus.metadata.tsv.gz
    echo -e "genome_id\\ttaxonomy" | gzip > uhbdb/test/Abiotrophia/Abiotrophia.metadata.tsv.gz
    """
}
