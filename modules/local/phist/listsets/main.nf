process PHIST_LISTSETS {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/cab6449d122c21a185b00ab64056d8f14c2c685777f30ba1bb88bbc4345239d9/data'
        : 'community.wave.seqera.io/library/agc_kmer-db_python:36c88a37ee2b3531'}"

    input:
    tuple val(meta), path(agc)
    val chunk_size

    output:
    tuple val(meta), path(agc), path("sample_chunks/chunk_*"), emit: sample_chunks

    script:
    """
    ### List sample names and split into chunks for in-job AGC extraction
    mkdir -p sample_chunks
    agc listset ${agc} | awk 'NF' > samples.txt

    if [ ! -s samples.txt ]; then
        : > sample_chunks/chunk_0000
    else
        split -l ${chunk_size} -d -a 4 samples.txt sample_chunks/chunk_
    fi
    """

    stub:
    """
    mkdir -p sample_chunks
    echo stub_sample > sample_chunks/chunk_0000
    """
}
