process VCLUST_ALL2ALL {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/bf/bfa8565537a8cc0a4699ec70019e63808279e435844e571dd796d1d53c120cc5/data"
    storeDir "${publish_dir}/${meta.id}/"

    input:
    tuple val(meta) , path(fna_gz)
    path(uhvdb_unique_fna_gz)
    val(min_ani)
    val(min_af)
    val(publish_dir)

    output:
    tuple val(meta), path("${meta.id}.clusters.tsv.gz")     , emit: tsv_gz
    tuple val(meta), path("${meta.id}.new_reps.fna.gz")     , emit: new_fna_gz
    tuple val(meta), path("${meta.id}.reps.fna.gz")         , emit: all_fna_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Combine fastas if uhvdb_unique_fna_gz is input
    if [ -s ${uhvdb_unique_fna_gz} ]; then
         cat ${fna_gz} ${uhvdb_unique_fna_gz} > ${meta.id}.combined.fna.gz
    else
        mv ${fna_gz} ${meta.id}.combined.fna.gz
    fi

    ### Run vClust
    vclust \\
        prefilter \\
        --in ${meta.id}.combined.fna.gz \\
        --out ${meta.id}.prefilter.txt \\
        --threads ${task.cpus} \\
        --min-ident ${min_ani}

    vclust \\
        align \\
        --in ${meta.id}.combined.fna.gz \\
        --out ${meta.id}.ani.tsv \\
        --filter ${meta.id}.prefilter.txt \\
        --threads ${task.cpus} \\
        --out-ani ${min_ani} \\
        --out-qcov ${min_af}

    vclust \\
        cluster \\
        --in ${meta.id}.ani.tsv \\
        --ids ${meta.id}.ani.ids.tsv \\
        --out ${meta.id}.clusters.tsv \\
        --algorithm cd-hit \\
        --metric ani \\
        --ani ${min_ani} \\
        --qcov ${min_af} \\
        --out-repr

    ### Extract new reps
    csvtk \\
        cut \\
        ${meta.id}.clusters.tsv \\
        --tabs \\
        --fields cluster | \\
    csvtk \\
        uniq \\
        --tabs \\
        --out-file ${meta.id}.reps.tsv

    seqkit \\
        grep \\
        ${fna_gz} \\
        --pattern-file ${meta.id}.reps.tsv \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}.new_reps.fna.gz

    ### Extract all reps
    seqkit \\
        grep \\
        ${meta.id}.combined.fna.gz  \\
        --pattern-file ${meta.id}.reps.tsv \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}.reps.fna.gz

    ### Compress
    gzip ${meta.id}.clusters.tsv

    ### Cleanup
    rm ${meta.id}.prefilter.txt ${meta.id}.ani.tsv ${meta.id}.ani.ids.tsv ${meta.id}.reps.tsv ${meta.id}.combined.fna.gz
    """
}
