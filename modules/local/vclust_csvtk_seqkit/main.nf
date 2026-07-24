process VCLUST_CSVTK_SEQKIT {
    tag "${meta.id}"
    label 'process_super_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e9/e9cecc56a1746efb711eb521ff695c2674295000eb97b333d9e23fba5fd32730/data'
        : 'community.wave.seqera.io/library/seqkit_vclust_csvtk:140f8e9170b6a206'}"

    input:
    tuple val(meta), path(fna_gz)

    output:
    tuple val(meta), path("*.reps.fna.gz")        , emit: fna_gz
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions
    tuple val("${task.process}"), val('vclust'), eval("vclust --version"), emit: versions_vclust, topic: versions
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed -e 's/seqkit v//g'"), emit: versions_seqkit, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Run vClust
    vclust \\
        prefilter \\
        --in ${fna_gz} \\
        --out ${prefix}.prefilter.txt \\
        --threads ${task.cpus} \\
        --kmers-fraction 0.2 \\
        --min-ident 0.95

    vclust \\
        align \\
        --in ${fna_gz} \\
        --out ${prefix}.ani.tsv \\
        --filter ${prefix}.prefilter.txt \\
        --threads ${task.cpus} \\
        --out-ani 0.95 \\
        --out-qcov 0.85

    vclust \\
        cluster \\
        -i ${prefix}.ani.tsv \\
        -o ${prefix}.cluster.tsv \\
        --ids ${prefix}.ani.ids.tsv \\
        --metric ani \\
        --ani 0.95 \\
        --qcov 0.85 \\
        --out-repr

    ### Extract cluster representatives
    csvtk cut \\
        ${prefix}.cluster.tsv \\
        --tabs \\
        --delete-header \\
        -f cluster --out-delimiter '\t' \\
        --out-file ${prefix}.cluster_reps.tsv.gz

    ### Extract cluster representatives
    seqkit grep \\
        ${fna_gz} \\
        --pattern-file ${prefix}.cluster_reps.tsv.gz \\
        --out-file ${prefix}.reps.fna.gz

    ### Cleanup
    rm ${prefix}.prefilter.txt
    rm ${prefix}.ani.tsv
    rm ${prefix}.ani.ids.tsv
    rm ${prefix}.cluster.tsv
    rm ${prefix}.cluster_reps.tsv.gz
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.reps.fna.gz
    """
}
