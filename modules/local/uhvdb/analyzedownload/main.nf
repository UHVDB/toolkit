process UHVDB_ANALYZEDOWNLOAD {
    label 'process_single'
    tag "UHVDB ${params.uhvdb_version} analyze"
    storeDir "${params.dbdir}/uhvdb/${params.uhvdb_version}/analyze"
    publishDir enabled: false
    errorStrategy { params.uhvdb_version == 'test' && task.attempt < 2 ? 'retry' : 'terminate' }
    maxRetries 1

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("uhvdb_metadata.tsv.gz")             , emit: metadata_tsv_gz
    path("uhvdb_metadata_sylphtax.tsv.gz")    , emit: metadata_sylphtax_tsv_gz
    path("uhvdb_unique_reps.fna.gz")          , emit: unique_reps_fna_gz
    path("uhvdb_proteins.faa.gz")             , emit: proteins_faa_gz
    path("uhvdb_protein_annotations.parquet") , emit: protein_annotations_parquet

    script:
    def base = "https://s3.kopah.uw.edu/uhvdb/${params.uhvdb_version}/analyze"
    """
    wget ${base}/uhvdb_metadata.tsv.gz
    wget ${base}/uhvdb_metadata_sylphtax.tsv.gz
    wget ${base}/uhvdb_unique_reps.fna.gz
    wget ${base}/uhvdb_proteins.faa.gz
    wget ${base}/uhvdb_protein_annotations.parquet
    """

    stub:
    """
    echo "" | gzip > uhvdb_metadata.tsv.gz
    echo "" | gzip > uhvdb_metadata_sylphtax.tsv.gz
    echo "" | gzip > uhvdb_unique_reps.fna.gz
    echo "" | gzip > uhvdb_proteins.faa.gz
    touch uhvdb_protein_annotations.parquet
    """
}
