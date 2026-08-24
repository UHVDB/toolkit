process UHVDB_UPDATEDOWNLOAD {
    label 'process_single'
    tag "UHVDB ${params.uhvdb_version} update"
    storeDir "${params.dbdir}/uhvdb/${params.uhvdb_version}/update"
    publishDir enabled: false
    errorStrategy { params.uhvdb_version == 'test' && task.attempt < 2 ? 'retry' : 'terminate' }
    maxRetries 1

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("uhvdb_genomovars_gani.tsv.gz")        , emit: genomovars_gani_tsv_gz
    path("uhvdb_species_gani.tsv.gz")           , emit: species_gani_tsv_gz
    path("uhvdb_proteinsimilarity.tsv.gz")      , emit: proteinsimilarity_tsv_gz
    path("uhvdb_ictv_proteinsimilarity.tsv.gz") , emit: ictv_proteinsimilarity_tsv_gz
    path("uhvdb_crispr.parquet")                , emit: crispr_parquet
    path("uhvdb_phist.parquet")                 , emit: phist_parquet
    path("uhvdb-checkv-db")                     , emit: checkv_db
    path("genomad_1_9_hallmarks.hmm")           , emit: genomad_1_9_hallmarks_hmm
    path("genomad_metadata_v1.9.tsv.gz")        , emit: genomad_metadata_v1_9_tsv_gz
    path("crispr_spacers.spire_progenomes3.fna.gz")           , emit: spacers_fna_gz
    path("crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz") , emit: spacers_tsv_gz

    script:
    def base = "https://s3.kopah.uw.edu/uhvdb/${params.uhvdb_version}/update"
    """
    wget ${base}/uhvdb_genomovars_gani.tsv.gz
    wget ${base}/uhvdb_species_gani.tsv.gz
    wget ${base}/uhvdb_proteinsimilarity.tsv.gz
    wget ${base}/uhvdb_ictv_proteinsimilarity.tsv.gz
    wget ${base}/uhvdb_crispr.parquet
    wget ${base}/uhvdb_phist.parquet
    wget ${base}/uhvdb-checkv-db.tar.gz
    wget ${base}/genomad_1_9_hallmarks.hmm
    wget ${base}/genomad_metadata_v1.9.tsv.gz
    wget ${base}/crispr_spacers.spire_progenomes3.fna.gz
    wget ${base}/crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz

    mkdir -p uhvdb-checkv-db
    tar -xzf uhvdb-checkv-db.tar.gz -C uhvdb-checkv-db --strip-components=1
    """

    stub:
    """
    echo "" | gzip > uhvdb_genomovars_gani.tsv.gz
    echo "" | gzip > uhvdb_species_gani.tsv.gz
    echo "" | gzip > uhvdb_proteinsimilarity.tsv.gz
    echo "" | gzip > uhvdb_ictv_proteinsimilarity.tsv.gz
    touch uhvdb_crispr.parquet
    touch uhvdb_phist.parquet
    echo "" | gzip > uhvdb-checkv-db.tar.gz
    mkdir -p uhvdb-checkv-db
    touch genomad_1_9_hallmarks.hmm
    echo "" | gzip > genomad_metadata_v1.9.tsv.gz
    echo "" | gzip > crispr_spacers.spire_progenomes3.fna.gz
    echo "" | gzip > crispr_spacers.progenomes3_spire.gtdb_r220.tsv.gz
    """
}
