process PHIST_AGC {
    tag "${meta.id}"
    label 'process_high'
    maxForks 50

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/cab6449d122c21a185b00ab64056d8f14c2c685777f30ba1bb88bbc4345239d9/data'
        : 'community.wave.seqera.io/library/agc_kmer-db_python:36c88a37ee2b3531'}"

    input:
    tuple val(meta), val(agcs)
    tuple val(meta2), path(virus_db)

    output:
    tuple val(meta), path("${meta.id}.phist.min.csv.gz"), emit: csv_gz

    script:
    def agc_lst = agcs.collect { agc -> agc.toString() }.join(' ')
    """
    ### Extract host FASTAs from AGC archives (temporary; cleaned up in this job)
    mkdir -p host_fastas

    for agc in ${agc_lst}; do
        agc getcol \\
            \${agc} \\
            -g 1 \\
            -o host_fastas/ \\
            -t ${task.cpus}
    done

    ### Run phist on virus kmer-db and host FASTAs
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
    gzip ${meta.id}.phist.csv ${meta.id}.phist.min.csv

    ### Cleanup
    rm -rf ${meta.id}.phist_preds.csv host_fastas/ ${meta.id}.phist.csv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.phist.min.csv.gz
    """
}
