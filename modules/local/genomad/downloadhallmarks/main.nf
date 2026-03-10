process GENOMAD_DOWNLOADHALLMARKS {
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0c/0c39703d881069a69d14e68d12258fd1a93f2a9bd17870f6f6ab39a6b63e094f/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-30e54ab816eb9c63_1?_gl=1*9mafpw*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    storeDir "${params.db_dir}/genomadhallmarks/1.9"
    tag "geNomad v1.9; db v1.11"

    output:
    path "genomad_1_9_hallmarks.hmm"    , emit: hmm
    path "genomad_metadata_v1.9.tsv.gz" , emit: tsv_gz
    path(".command.log")                , emit: log
    path(".command.sh")                 , emit: script

    script:
    def filter1         = '( \$PLASMID_HALLMARK == 1 )'
    def filter2         = '( \$VIRUS_HALLMARK == 1 )'
    """
    ### Download geNomad data
    wget https://zenodo.org/records/14886553/files/genomad_hmm_v1.9.tar.gz?download=1 -O genomad_hmm_v1.9.tar.gz
    wget https://zenodo.org/records/14886553/files/genomad_metadata_v1.9.tsv.gz?download=1 -O genomad_metadata_v1.9.tsv.gz
    
    ### Identify hallmarks
    csvtk filter2 \\
        genomad_metadata_v1.9.tsv.gz \\
        --tabs \\
        --filter '${filter1} || ${filter2}' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields "MARKER" \\
        --delete-header \\
        --out-file filtered_genomad.txt

    sed 's/^/genomad_hmm_v1.9//g; s/\$/.hmm/g' filtered_genomad.txt > hallmark_hmms.txt

    ### Extract hallmarks
    gunzip genomad_hmm_v1.9.tar.gz
    tar -xvf genomad_hmm_v1.9.tar --files-from genomad_hallmarks_hmms.txt

    ### Combine hallmarks
    cat genomad_hmm_v1.9/*.hmm > genomad_1_9_hallmarks.hmm

    ### Cleanup
    rm -rf genomad_hmm_v1.9.tar.gz genomad_hmm_v1.9.tar filtered_genomad.txt hallmark_hmms.txt genomad_hmm_v1.9/
    """
}
