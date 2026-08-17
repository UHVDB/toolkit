process UHVDB_DOWNLOAD {
    label 'process_single'
    tag "UHVDB 5.${params.uhvdb_version}"
    storeDir "${params.dbdir}/uhvdb/${params.uhvdb_version}"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("uhvdb_metadata.tsv.gz")               , emit: metadata_tsv_gz
    path("uhvdb_metadata_sylphtax.tsv.gz")      , emit: metadata_sylphtax_tsv_gz, optional: true
    path("uhvdb_unique_reps.fna.gz")            , emit: unique_reps_fna_gz
    path("uhvdb_genomovars_gani.tsv.gz")        , emit: genomovars_gani_tsv_gz
    path("uhvdb_species_gani.tsv.gz")           , emit: species_gani_tsv_gz
    path("uhvdb_proteins.faa.gz")               , emit: proteins_faa_gz
    path("uhvdb_proteinsimilarity.tsv.gz")      , emit: proteinsimilarity_tsv_gz
    path("uhvdb_protein_annotations.tsv.gz")    , emit: protein_annotations_tsv_gz
    path("uhvdb_ictv_hits.tsv.gz")              , emit: ictv_hits_tsv_gz, optional: true
    path("uhvdb_crispr.tsv.gz")                 , emit: crispr_tsv_gz, optional: true
    path("uhvdb_phist.tsv.gz")                  , emit: phist_tsv_gz, optional: true

    script:
    if ( task.attempt == 1 ) {
        """
        # download UHVDB tarball
        wget https://s3.kopah.uw.edu/uhvdb/v5/uhvdb.tar.gz

        # extract UHVDB tarball
        tar -xzf uhvdb.tar.gz

        # clean up tarball
        rm uhvdb.tar.gz
        """
    }

    // TODO: add zenodo fallback

    stub:
    """
    echo "" | gzip > uhvdb_metadata.tsv.gz
    echo "" | gzip > uhvdb_metadata_sylphtax.tsv.gz
    echo "" | gzip > uhvdb_unique_reps.fna.gz
    echo "" | gzip > uhvdb_genomovars_gani.tsv.gz
    echo "" | gzip > uhvdb_protein_annotations.tsv.gz
    echo "" | gzip > uhvdb_proteinsimilarity.tsv.gz
    echo "" | gzip > uhvdb_species_gani.tsv.gz
    echo "" | gzip > uhvdb_proteins.faa.gz
    echo "" | gzip > uhvdb_ictv_hits.tsv.gz
    echo "" | gzip > uhvdb_crispr.tsv.gz
    echo "" | gzip > uhvdb_phist.tsv.gz
    """
}
