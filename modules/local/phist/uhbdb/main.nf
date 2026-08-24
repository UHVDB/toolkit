process PHIST_UHBDB {
    tag "${meta.id}"
    label 'process_super_high'
    maxForks 10

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/cab6449d122c21a185b00ab64056d8f14c2c685777f30ba1bb88bbc4345239d9/data'
        : 'community.wave.seqera.io/library/agc_kmer-db_python:36c88a37ee2b3531'}"

    input:
    tuple val(meta), path(agc), path(sample_list)
    tuple val(meta2), path(virus_db)

    output:
    tuple val(meta), path("${meta.id}.phist.min.csv.gz"), emit: csv_gz

    script:
    """
    ### Skip empty sample chunks
    if [ ! -s ${sample_list} ]; then
        printf '' | gzip > ${meta.id}.phist.min.csv.gz
        exit 0
    fi

    ### Extract one gzipped FASTA per sample (same layout as agc getcol -g 1)
    ### Do not split on contig headers: that multiplies files and breaks genome IDs
    mkdir -p host_fastas
    while IFS= read -r sample || [ -n "\$sample" ]; do
        [ -z "\$sample" ] && continue
        agc getset \\
            -t ${task.cpus} \\
            -p \\
            -g 1 \\
            -o "host_fastas/\${sample}.fa.gz" \\
            ${agc} \\
            "\$sample"
    done < ${sample_list}

    if [ -z "\$(find -L host_fastas -type f | head -n 1)" ]; then
        printf '' | gzip > ${meta.id}.phist.min.csv.gz
        rm -rf host_fastas
        exit 0
    fi

    ### Run phist on virus kmer-db and host FASTA chunk
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
    rm -rf host_fastas ${meta.id}.phist_preds.csv ${meta.id}.phist.csv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.phist.min.csv.gz
    """
}
