process VCLUST_CSVTK {
    tag "${meta.id}"
    label 'process_super_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2e/2e1ae7bd48dd9021e08a4c4f804a3c5ed65a50b6ef029b7639caec57cc3abe6d/data'
        : 'community.wave.seqera.io/library/vclust_csvtk:0be226ba74e71663'}"

    input:
    tuple val(meta), path(fna_gz)
    val min_ani
    val min_qcov

    output:
    tuple val(meta), path("*.ani.tsv.gz")   , emit: lzani_tsv_gz
    tuple val(meta), path("*.gani.tsv.gz")  , emit: gani_tsv_gz
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions
    tuple val("${task.process}"), val('vclust'), eval("vclust --version"), emit: versions_vclust, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}.new2new"
    """
    ### Run vClust
    vclust \\
        prefilter \\
        --in ${fna_gz} \\
        --out ${prefix}.prefilter.txt \\
        --threads ${task.cpus} \\
        --kmers-fraction 0.2 \\
        --min-ident ${min_ani}

    vclust \\
        align \\
        --in ${fna_gz} \\
        --out ${prefix}.ani.tsv \\
        --filter ${prefix}.prefilter.txt \\
        --threads ${task.cpus} \\
        --out-ani ${min_ani} \\
        --out-qcov ${min_qcov}

    ### Convert to gani
    csvtk cut \\
        ${prefix}.ani.tsv \\
        --tabs \\
        --out-tabs \\
        --delete-header \\
        --fields query,reference,gani \\
        --out-file ${prefix}.gani.tsv.gz

    ### Compress
    gzip ${prefix}.ani.tsv

    ### Cleanup
    rm ${prefix}.prefilter.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.new2new"
    """
    echo "" | gzip >  ${prefix}.gani.tsv.gz
    echo "" | gzip >  ${prefix}.lzani.tsv.gz
    """
}
