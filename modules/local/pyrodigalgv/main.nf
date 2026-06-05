process PYRODIGALGV {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/49/49cb5d89811a391191e73485863ff79d9f5fa61e9a8bd4636fb936f54737ccc0/data':
        'community.wave.seqera.io/library/pyrodigal-gv_pigz:10a8e2bb588f032e' }"

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("*.faa.gz")                   , emit: faa_gz
    tuple val("${task.process}"), val('pyrodigal-gv'), eval("pyrodigal-gv --version |& sed 's/pyrodigal-gv v//'"), emit: versions_pyrodigal_gv, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    pigz -cdf ${fasta} > pigz_fasta.fna

    pyrodigal-gv \\
        -j ${task.cpus} \\
        $args \\
        -i pigz_fasta.fna \\
        -a ${prefix}.faa \\
        > /dev/null 2>&1

    pigz -nmf ${prefix}.faa
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.faa.gz
    """
}