process PHIST_UHBDB {
    tag "${meta.id}"
    label 'process_high'
    maxForks 50

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

    ### Extract this sample chunk from the AGC in-job (no persistent host store)
    mkdir -p host_fastas
    batch=()
    flush_batch() {
        if [ \${#batch[@]} -eq 0 ]; then
            return
        fi
        agc getset \\
            -t ${task.cpus} \\
            ${agc} \\
            "\${batch[@]}" | awk -v d=host_fastas '
                /^>/ {
                    close(f)
                    name = substr(\$1, 2)
                    gsub(/[^A-Za-z0-9._+-]/, "_", name)
                    f = d "/" name ".fna"
                    print > f
                    next
                }
                { print > f }
            '
        batch=()
    }
    while IFS= read -r sample || [ -n "\$sample" ]; do
        [ -z "\$sample" ] && continue
        batch+=("\$sample")
        if [ \${#batch[@]} -ge 100 ]; then
            flush_batch
        fi
    done < ${sample_list}
    flush_batch

    if [ -z "\$(find host_fastas -type f | head -n 1)" ]; then
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
