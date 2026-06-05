process MCL {
    tag "${meta.id}"
    label 'process_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/aa/aa8c88af6c3882c32a1ff9d0ecfd96a8d60daae89312099c4f23761f511971a0/data'
        : 'community.wave.seqera.io/library/mcl:22.282--9de127ffaefcac2f'}"

    input:
    tuple val(meta), path(tsv_gz)

    output:
    tuple val(meta), path("*.mcl.gz")      , emit: mcl_gz
    tuple val("${task.process}"), val('mcl'), eval('mcl --version'), topic: versions, emit: versions_mcl

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Decompress
    gunzip -c ${tsv_gz} > ${prefix}.txt

    ### Run MCL
    mcl \\
        ${prefix}.txt \\
        --abc \\
        -sort revsize \\
        -te ${task.cpus} \\
        -o ${prefix}.mcl

    ### Compress
    gzip ${prefix}.mcl

    ### Cleanup
    rm ${prefix}.txt
    """
}
