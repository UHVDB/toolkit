process DEACON_INDEXFETCH {
    tag "${index_name}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/deacon:0.13.2--h7ef3eeb_1':
        'quay.io/biocontainers/deacon:0.13.2--h7ef3eeb_0' }"

    input:
    val index_name

    output:
    path "*.idx", emit: idx
    // tuple val("${task.process}"), val('deacon'), eval('deacon --version | head -n1 | sed "s/deacon //g"'), emit: versions_deacon, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    deacon \\
        index \\
        fetch \\
        ${index_name}
    """

    stub:
    """
    touch ${index_name}.idx
    """
}
