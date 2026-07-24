process UHVDB_AAICLUSTER {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c5/c54a858d4e1e2b37fa25fdef57ef3d42549df7822135f66b86b3ca66a97936de/data':
        'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071' }"

    input:
    tuple val(meta) , path(new_fna_gz)
    tuple val(meta2), path(old_fna_gz)
    tuple val(meta3), path(family_mcl)
    tuple val(meta4), path(subfamily_mcl)
    tuple val(meta5), path(genus_mcl)
    tuple val(meta6), path(subgenus_mcl)

    output:
    tuple val(meta) , path("*.tsv.gz") , emit: tsv_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('uhvdb_aaicluster'), eval('uhvdb_aaicluster.py --version'), topic: versions, emit: versions_uhvdb_aaicluster


    script:
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    ### Combine new and old species reps ids
    zcat ${new_fna_gz} ${old_fna_gz} | grep "^>" | sed 's/>//g; s/\s.*//' >> ${prefix}.all_ids.txt

    ### Generate cluster assignments at each rank
    uhvdb_aaicluster.py \\
        --species-reps ${prefix}.all_ids.txt \\
        --family ${family_mcl} \\
        --subfamily ${subfamily_mcl} \\
        --genus ${genus_mcl} \\
        --subgenus ${subgenus_mcl} \\
        -o ${prefix}.tsv

    ### Compress
    gzip ${prefix}.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.tsv.gz
    """
}
