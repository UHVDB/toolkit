process PHIST_EXTRACTHOSTS {
    tag "${meta.id}"
    label 'process_super_high'
    maxForks 50

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/cab6449d122c21a185b00ab64056d8f14c2c685777f30ba1bb88bbc4345239d9/data'
        : 'community.wave.seqera.io/library/agc_kmer-db_python:36c88a37ee2b3531'}"

    input:
    tuple val(meta), path(agc)
    val chunk_size

    output:
    tuple val(meta), path("host_chunks/chunk_*.tar.gz"), emit: host_chunks

    script:
    """
    ### Extract host genomes as gzipped FASTAs
    mkdir -p host_fastas
    agc getcol \\
        ${agc} \\
        -g 1 \\
        -o host_fastas/ \\
        -t ${task.cpus}

    ### Partition into compressed chunk archives for parallel PHIST
    mkdir -p host_chunks
    chunk_idx=0
    n_in_chunk=0
    chunk_dir=\$(printf "chunk_%04d" \${chunk_idx})
    mkdir -p "\${chunk_dir}"

    shopt -s nullglob
    for fasta in host_fastas/*; do
        if [ \${n_in_chunk} -ge ${chunk_size} ]; then
            tar -czf "host_chunks/\${chunk_dir}.tar.gz" -C "\${chunk_dir}" .
            rm -rf "\${chunk_dir}"
            chunk_idx=\$((chunk_idx + 1))
            n_in_chunk=0
            chunk_dir=\$(printf "chunk_%04d" \${chunk_idx})
            mkdir -p "\${chunk_dir}"
        fi
        mv "\${fasta}" "\${chunk_dir}/"
        n_in_chunk=\$((n_in_chunk + 1))
    done

    if [ \${n_in_chunk} -gt 0 ]; then
        tar -czf "host_chunks/\${chunk_dir}.tar.gz" -C "\${chunk_dir}" .
        rm -rf "\${chunk_dir}"
    elif [ ! -f host_chunks/chunk_0000.tar.gz ]; then
        mkdir -p chunk_0000
        touch chunk_0000/.empty
        tar -czf host_chunks/chunk_0000.tar.gz -C chunk_0000 .
        rm -rf chunk_0000
    fi

    rm -rf host_fastas
    """

    stub:
    """
    mkdir -p chunk_0000 host_chunks
    touch chunk_0000/stub.fna.gz
    tar -czf host_chunks/chunk_0000.tar.gz -C chunk_0000 .
    """
}
