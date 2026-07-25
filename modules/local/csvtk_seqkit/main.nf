process CSVTK_SEQKIT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/cf/cf49f65f848491c6911b97579eaf88784f880410b6c341a120360ebffde6a359/data' :
        'community.wave.seqera.io/library/seqkit_csvtk:58eb2229bdfb9934' }"

    input:
    tuple val(meta), path(csv), path(fasta)
    val args
    val args2
    val prefix_suffix

    output:
    tuple val(meta), path("*.fna.gz"), emit: fna_gz

    script:
    def prefix = "${meta.id}.${prefix_suffix}"
    """
    ### Filter CSV file
    csvtk \\
        filter2 \\
        ${csv} \\
        --num-cpus ${task.cpus} \\
        ${args} \\
        --out-file ${prefix}.tsv

    ### Filter FASTA file
    seqkit \\
        grep \\
        ${fasta} \\
        ${args2} \\
        --pattern-file ${prefix}.tsv \\
        --out-file ${prefix}.fna.gz

    ### Cleanup
    rm -rf ${prefix}.tsv
    """

    stub:
    def prefix = "${meta.id}.${prefix_suffix}"
    """
    echo "" | gzip > ${prefix}.fna.gz
    """
}
