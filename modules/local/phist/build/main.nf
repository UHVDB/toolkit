process PHIST_BUILD {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/99/99cdbbc8ee707435804fe59e2b78583703a8204b91b88681eb04e4cc1ec8bb23/data'
        : 'community.wave.seqera.io/library/kmer-db_lz-ani_seqkit_csvtk_python:7922d65ae24d9f78'}"

    input:
    tuple val(meta), path(fnas, stageAs: 'input_fastas/*')

    output:
    tuple val(meta), path("virus.kdb"), emit: kdb

    script:
    """
    ### Build kmer-db from all virus FASTAs
    # Nextflow stages inputs as symlinks; -type f misses those, so use -L
    find -L input_fastas -type f | sort > input.list
    test -s input.list

    kmer-db build \\
        -k 25 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        input.list \\
        virus.kdb
    """

    stub:
    """
    touch virus.kdb
    """
}
