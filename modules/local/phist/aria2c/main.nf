process PHIST_ARIA2C {
    tag "${meta.id}"
    label "process_high"
    maxForks 50
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2d/2da893faa291c2c37400521fb3fa380961985fef70dcda9d250eb469ec90ca31/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-3d125c4d72f5a9ac_1?_gl=1*13x4irc*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , val(urls)
    tuple val(meta2), path(virus_db)

    output:
    tuple val(meta), path("${meta.id}.phist.csv.gz")    , emit: csv_gz
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    def download_list   = urls.collect { url -> url.toString() }.join(',')
    """
    ### Create an input file for aria2c
    IFS=',' read -r -a download_array <<< "${download_list}"
    printf '%s\\n' "\${download_array[@]}" > aria2_file.tsv

    ### Download fasta files with aria2c
    aria2c \\
        --input=aria2_file.tsv \\
        --dir=host_fastas \\
        --max-concurrent-downloads=${task.cpus}

    ### Run phist on virus fasta and host fasta chunk
    phist.py \\
        ${virus_db} \\
        host_fastas/ \\
        ${meta.id}.phist.csv \\
        ${meta.id}.phist_preds.csv \\
        -t ${task.cpus}

    kmer-db distance \\
        min \\
        -min 0.2 \\
        ${meta.id}.phist.csv \\
        ${meta.id}.phist.min.csv

    ### Compress
    gzip ${meta.id}.phist.csv

    ### Cleanup
    # rm -rf ${meta.id}.phist_preds.csv host_fastas/ ${meta.id}.phist.csv
    """
}