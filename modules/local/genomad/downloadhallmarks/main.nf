process GENOMAD_DOWNLOADHALLMARKS {
    label 'process_single'
    tag "genomad_hallmarks 1.9"
    storeDir "${params.dbdir}/genomad_hallmarks/1.9"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/1b/1b12953f793564802e8d1308122cb5f9a17aa7ee0a969ede65eeabfd5302f0e5/data'
        : 'community.wave.seqera.io/library/csvtk_wget:db39790d6152cb10'}"

    output:
    path "genomad_1_9_hallmarks.hmm"    , emit: hmm
    path "genomad_metadata_v1.9.tsv.gz" , emit: tsv_gz

    script:
    """
    # download geNomad data
    wget https://zenodo.org/records/14886553/files/genomad_hmm_v1.9.tar.gz?download=1 -O genomad_hmm_v1.9.tar.gz
    wget https://zenodo.org/records/14886553/files/genomad_metadata_v1.9.tsv.gz?download=1 -O genomad_metadata_v1.9.tsv.gz

    # identify hallmarks
    csvtk filter2 \\
        genomad_metadata_v1.9.tsv.gz \\
        --tabs \\
        --filter '( \$PLASMID_HALLMARK == 1 ) | ( \$VIRUS_HALLMARK == 1 )' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields "MARKER" \\
        --delete-header \\
        --out-file filtered_genomad.txt

    sed 's|^|genomad_hmm_v1.9/|g; s|\$|.hmm|g' filtered_genomad.txt > hallmark_hmms.txt

    # extract hallmarks
    gunzip genomad_hmm_v1.9.tar.gz
    tar -xvf genomad_hmm_v1.9.tar --files-from hallmark_hmms.txt

    # combine hallmarks
    cat genomad_hmm_v1.9/*.hmm > genomad_1_9_hallmarks.hmm

    # cleanup
    rm -rf genomad_hmm_v1.9.tar.gz genomad_hmm_v1.9.tar filtered_genomad.txt hallmark_hmms.txt genomad_hmm_v1.9/
    """

    stub:
    """
    touch genomad_1_9_hallmarks.hmm
    echo "" | gzip > genomad_metadata_v1.9.tsv.gz
    """
}
