process CSVTK_FILTER2 {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/91/917edb71b915f07fa2838c20e3c731181d3d315cbf8a9bfead41412d2b4ae062/data' :
        'community.wave.seqera.io/library/csvtk:0.37.0--113625988dd3285d' }"

    input:
    tuple val(meta), path(csv)

    output:
    tuple val(meta), path("${prefix}.${out_extension}"), emit: csv

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    out_extension = args.contains('--out-delimiter "\t"') || args.contains('-D "\t"') || args.contains("-D \$'\t'") ? "tsv" : "csv"
    """
    csvtk \\
        filter2 \\
        $csv \\
        --num-cpus $task.cpus \\
        $args \\
        --out-file ${prefix}.${out_extension}

    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    out_extension = args.contains('--out-delimiter "\t"') || args.contains('-D "\t"') || args.contains("-D \$'\t'") ? "tsv" : "csv"
    """
    touch ${prefix}.${out_extension}
    """
}
