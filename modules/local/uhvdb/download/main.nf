process UHVDB_DOWNLOAD {
    label 'process_single'
    tag "UHVDB ${params.uhvdb_version}"
    storeDir "${params.dbdir}/uhvdb/${params.uhvdb_version}"
    publishDir enabled: false
    errorStrategy { params.uhvdb_version == 'test' && task.attempt < 2 ? 'retry' : 'terminate' }
    maxRetries 1

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("uhvdb_metadata.tsv.gz")               , emit: metadata_tsv_gz
    path("uhvdb_metadata_sylphtax.tsv.gz")      , emit: metadata_sylphtax_tsv_gz
    path("uhvdb_unique_reps.fna.gz")            , emit: unique_reps_fna_gz
    path("uhvdb_genomovars_gani.tsv.gz")        , emit: genomovars_gani_tsv_gz
    path("uhvdb_species_gani.tsv.gz")           , emit: species_gani_tsv_gz
    path("uhvdb_proteins.faa.gz")               , emit: proteins_faa_gz
    path("uhvdb_proteinsimilarity.tsv.gz")      , emit: proteinsimilarity_tsv_gz
    path("uhvdb_protein_annotations.parquet")   , emit: protein_annotations_parquet
    path("uhvdb_ictv_proteinsimilarity.tsv.gz") , emit: ictv_proteinsimilarity_tsv_gz
    path("uhvdb_crispr.tsv.gz")                 , emit: crispr_tsv_gz
    path("uhvdb_phist.tsv.gz")                  , emit: phist_tsv_gz

    script:
    def is_test = params.uhvdb_version == 'test'
    if ( is_test && task.attempt == 2 ) {
        """
        wget -O uhvdb_test.tar.gz https://s3.kopah.uw.edu/uhvdb/test/uhvdb_test.tar.gz
        tar -xzf uhvdb_test.tar.gz
        rm -f uhvdb_test.tar.gz

        for f in *_test.*; do
            [ -e "\$f" ] || continue
            mv "\$f" "\${f/_test./.}"
        done
        """
    } else if ( is_test ) {
        """
        wget -O uhvdb_test.tar https://zenodo.org/records/21999114/files/uhvdb_test.tar?download=1
        tar -xf uhvdb_test.tar
        rm -f uhvdb_test.tar

        for f in *_test.*; do
            [ -e "\$f" ] || continue
            mv "\$f" "\${f/_test./.}"
        done
        """
    } else if ( task.attempt == 1 ) {
        """
        # download UHVDB tarball
        wget -O uhvdb.tar.gz https://s3.kopah.uw.edu/uhvdb/${params.uhvdb_version}/uhvdb.tar.gz

        # extract UHVDB tarball
        tar -xzf uhvdb.tar.gz

        # clean up tarball
        rm uhvdb.tar.gz
        """
    }

    stub:
    """
    echo "" | gzip > uhvdb_metadata.tsv.gz
    echo "" | gzip > uhvdb_metadata_sylphtax.tsv.gz
    echo "" | gzip > uhvdb_unique_reps.fna.gz
    echo "" | gzip > uhvdb_genomovars_gani.tsv.gz
    echo "" | gzip > uhvdb_proteinsimilarity.tsv.gz
    echo "" | gzip > uhvdb_species_gani.tsv.gz
    echo "" | gzip > uhvdb_proteins.faa.gz
    echo "" | gzip > uhvdb_ictv_proteinsimilarity.tsv.gz
    echo "" | gzip > uhvdb_crispr.tsv.gz
    echo "" | gzip > uhvdb_phist.tsv.gz
    touch uhvdb_protein_annotations.parquet
    """
}
