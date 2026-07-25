process SEQKIT_SEQ_REPLACE_SPLIT2 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/4f/4fe272ab9a519cf418160471a485b5ef50ea3f571a8e4555a826f70a4d8243ae/data' :
        'community.wave.seqera.io/library/seqkit:2.13.0--05c0a96bf9fb2751' }"

    input:
    tuple val(meta), path(fastx)

    output:
    tuple val(meta), path("${prefix}/*"), emit: fastx

    script:
    prefix      = task.ext.prefix   ?: "${meta.id}"
    """
    seqkit \\
        seq \\
        --remove-gaps \\
        --upper-case \\
        --validate-seq \\
        --min-len 2000 \\
        --threads $task.cpus \\
        $fastx \\
    | seqkit \\
        replace \\
        --pattern '^' \\
        --replacement ${prefix}_ \\
    | seqkit split2 \\
        --by-size 1000 \\
        --threads $task.cpus \\
        --out-dir ${prefix} \\
        -e .gz
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    echo "" | gzip > ${prefix}/${prefix}.fna.gz
    """
}
