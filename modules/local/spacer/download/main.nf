process SPACER_DOWNLOAD {
    label 'process_single'
    tag "crisprhost 1.0"
    storeDir "${params.dbdir}/crisprhost/1.0"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("crispr_spacers.spire_progenomes3.fna.gz")             , emit: fna_gz
    path("crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz")   , emit: tsv_gz

    script:
    """
    wget https://s3.kopah.uw.edu/uhvdb/v5/crispr_spacers.spire_progenomes3.fna.gz
    wget https://s3.kopah.uw.edu/uhvdb/v5/crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz
    """

    stub:
    """
    echo "" | gzip > crispr_spacers.spire_progenomes3.fna.gz
    echo "" | gzip > crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz
    """
}
