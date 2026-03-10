process PHIST_DATASETS {
    tag "${meta.id}"
    label "process_super_high"
    maxForks 50
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/3c/3c3e6d9557bf86b2e4070f1e9cb03268872dfa1c5384c9de9057e8d8a703c57e/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-2e9061c374408937_1?_gl=1*vi5ehm*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta) , val(urls)
    tuple val(meta2), path(virus_db)

    output:
    tuple val(meta), path("${meta.id}.phist.min.csv.gz")    , emit: csv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    def download_list   = urls.collect { url -> url.toString() }.join(',')
    """
    ### Create input file
    IFS=',' read -r -a download_array <<< "${download_list}"
    printf '%s\\n' "\${download_array[@]}" > accession_file.txt

    ### Download genomes
    for try in {1..6}; do
        rm -rf ${meta.id}.zip ${meta.id}_tmp/ || true

        datasets \\
            download genome accession \\
            --inputfile accession_file.txt \\
            --dehydrated \\
            --filename ${meta.id}.zip


        unzip ${meta.id}.zip -d ${meta.id}_tmp

        datasets \\
            rehydrate \\
            --directory ${meta.id}_tmp \
            --gzip \\
            --max-workers ${task.cpus} && break || sleep \$((\$try^2*120))

        rm -rf ${meta.id}.zip ${meta.id}_tmp/
    done
        

    mkdir -p ${meta.id}_fastas
    mv ${meta.id}_tmp/ncbi_dataset/data/*/*.fna.gz ${meta.id}_fastas/
    rm -rf ${meta.id}_tmp

    ### Run phist
    phist.py \\
        ${virus_db} \\
        ${meta.id}_fastas/ \\
        ${meta.id}.phist.csv \\
        ${meta.id}.phist_preds.csv \\
        -t ${task.cpus}

    kmer-db distance \\
        min \\
        -min 0.2 \\
        ${meta.id}.phist.csv \\
        ${meta.id}.phist.min.csv

    ### Compress
    gzip ${meta.id}.phist.min.csv

    ### Cleanup
    rm -rf ${meta.id}.phist_preds.csv ${meta.id}.phist.csv ${meta.id}_fastas
    """
}
