process DEACON_INDEXFETCH {
    tag "deacon 0.13.2"
    label 'process_low'
    storeDir "${params.dbdir}/deacon/0.13.2"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/deacon:0.13.2--h7ef3eeb_1':
        'quay.io/biocontainers/deacon:0.13.2--h7ef3eeb_0' }"

    output:
    path "*.idx", emit: idx

    script:
    """
    # download deacon index
    deacon \\
        index \\
        fetch \\
        panhuman-1
    """

    stub:
    """
    touch panhuman-1.idx
    """
}
