process UHVDB_DOWNLOAD {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    input:
    val uhvdb_s3
    val uhvdb_zenodo

    output:
    path("uhvdb_metadata.tsv.gz")               , emit: metadata_tsv_gz
    path("uhvdb_metadata_sylphtax.tsv.gz")      , emit: metadata_sylphtax_tsv_gz
    path("uhvdb_unique_reps.fna.gz")            , emit: unique_reps_fna_gz
    path("uhvdb_genomovars_gani.tsv.gz")        , emit: genomovars_gani_tsv_gz
    path("uhvdb_species_gani.tsv.gz")           , emit: species_gani_tsv_gz
    path("uhvdb_proteins.faa.gz")               , emit: proteins_faa_gz
    path("uhvdb_proteinsimilarity.tsv.gz")      , emit: proteinsimilarity_tsv_gz
    path("uhvdb_protein_annotations.tsv.gz")    , emit: protein_annotations_tsv_gz
    tuple val("${task.process}"), val('wget'), eval('wget --version | head -1 | cut -d " " -f 3'), emit: versions_wget, topic: versions_wget
    tuple val("${task.process}"), val('unzip'), eval('unzip --version | head -1 | cut -d " " -f 4'), emit: versions_unzip, topic: versions_unzip
    tuple val("${task.process}"), val('uhvdb'), val('v5.1.0'), emit: versions_uhvdb, topic: versions_uhvdb

    when:
    task.ext.when == null || task.ext.when

    script:
    if ( task.attempt == 1 ) {
        """
        ### Download UHVDB files
        wget ${uhvdb_s3}uhvdb_metadata.tsv.gz
        wget ${uhvdb_s3}uhvdb_metadata_sylphtax.tsv.gz
        wget ${uhvdb_s3}uhvdb_unique_reps.fna.gz
        wget ${uhvdb_s3}uhvdb_genomovars_gani.tsv.gz
        wget ${uhvdb_s3}uhvdb_species_gani.tsv.gz
        wget ${uhvdb_s3}uhvdb_proteins.faa.gz
        wget ${uhvdb_s3}uhvdb_proteinsimilarity.tsv.gz
        wget ${uhvdb_s3}uhvdb_protein_annotations.tsv.gz
        """
    } else {
        """
        ### Download UHVDB files
        wget ${uhvdb_zenodo} -O uhvdb.zip

        ### Extract UHVDB files
        unzip uhvdb.zip

        ### Rename files
        mv *_metadata.tsv.gz uhvdb_metadata.tsv.gz
        mv *_unique_reps.fna.gz uhvdb_unique_reps.fna.gz
        mv *_protein_annotations.tsv.gz uhvdb_protein_annotations.tsv.gz
        mv *_proteinsimilarity.tsv.gz uhvdb_proteinsimilarity.tsv.gz
        mv *_species_gani.tsv.gz uhvdb_species_gani.tsv.gz
        mv *_genomovars_gani.tsv.gz uhvdb_genomovars_gani.tsv.gz
        mv *_protein*.faa.gz uhvdb_proteins.faa.gz

        ### Cleanup
        rm uhvdb.zip
        """
    }

    stub:
    """
    ### Create empty files
    echo "" | gzip > uhvdb_metadata.tsv.gz
    echo "" | gzip > uhvdb_metadata_sylphtax.tsv.gz
    echo "" | gzip > uhvdb_unique_reps.fna.gz
    echo "" | gzip > uhvdb_genomovars_gani.tsv.gz
    echo "" | gzip > uhvdb_protein_annotations.tsv.gz
    echo "" | gzip > uhvdb_proteinsimilarity.tsv.gz
    echo "" | gzip > uhvdb_species_gani.tsv.gz
    echo "" | gzip > uhvdb_proteins.faa.gz
    """
}
