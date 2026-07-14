process CHECKV_DOWNLOAD {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/3b/3b54fa9135194c72a18d00db6b399c03248103f87e43ca75e4b50d61179994b3/data'
        : 'community.wave.seqera.io/library/wget:1.21.4--8b0fcde81c17be5e'}"

    input:
    val checkv_s3
    val checkv_zenodo

    output:
    path "checkv_db", emit: checkv_db
    // tuple val("${task.process}"), val('wget'), eval('wget --version | head -1 | cut -d " " -f 3'), emit: versions_wget, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    if ( task.attempt == 1 ) {
        """
        ### Download database
        wget ${checkv_s3}checkv_db.tar.gz

        ### Extract database
        mkdir -p checkv_db tmp
        tar -xvf checkv_db.tar.gz -C ./tmp
        mv tmp/*/*/ checkv_db/

        ### Cleanup
        rm checkv_db.tar.gz
        """
    } else {
        """
        ### Download UHVDB files
        wget ${checkv_zenodo} -O checkv_db.tar.gz

        ### Extract UHVDB files
        mkdir -p checkv_db tmp
        tar -xvf checkv_db.tar.gz -C ./tmp
        mv tmp/*/*/ checkv_db/

        ### Cleanup
        rm checkv_db.tar.gz
        """
    }
    stub:
    """
    ### Touch empty database files
    mkdir -p checkv_db
    touch checkv_db/README.txt
    mkdir -p checkv_db/genome_db
    touch checkv_db/genome_db/changelog.tsv
    touch checkv_db/genome_db/checkv_error.tsv
    touch checkv_db/genome_db/checkv_info.tsv
    touch checkv_db/genome_db/checkv_reps.faa
    touch checkv_db/genome_db/checkv_reps.fna
    touch checkv_db/genome_db/checkv_reps.tsv
    mkdir -p checkv_db/hmm_db
    touch checkv_db/hmm_db/checkv_hmms.tsv
    touch checkv_db/hmm_db/genome_lengths.tsv
    """
}
