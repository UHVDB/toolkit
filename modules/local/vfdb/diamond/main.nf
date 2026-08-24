process VFDB_DIAMOND {
    tag "${meta.id}"
    label 'process_super_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data' :
        'quay.io/biocontainers/diamond:2.1.11--h5ca1c30_0' }"

    input:
    tuple val(meta), path(faa_gz)
    path(dmnd)

    output:
    tuple val(meta), path("${meta.id}.vfdb.tsv.gz"), emit: tsv_gz

    script:
    """
    ### Run DIAMOND
    diamond \\
        blastp \\
        --very-sensitive --iterate --max-target-seqs 1 --id 80 --query-cover 40 --subject-cover 40 \\
        --query ${faa_gz} \\
        --db ${dmnd} \\
        --threads ${task.cpus} \\
        --outfmt 6 \\
        --out ${meta.id}.vfdb.tsv

    ### Compress
    gzip ${meta.id}.vfdb.tsv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.vfdb.tsv.gz
    """
}
