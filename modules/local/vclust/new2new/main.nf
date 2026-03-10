process VCLUST_NEW2NEW {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/bf/bfa8565537a8cc0a4699ec70019e63808279e435844e571dd796d1d53c120cc5/data"

    input:
    tuple val(meta) , path(fna_gz)

    output:
    tuple val(meta), path("${meta.id}.ani.tsv.gz")          , emit: ani_gz
    tuple val(meta), path("${meta.id}.gani_new2new.tsv.gz") , emit: gani_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Run vClust
    vclust \\
        prefilter \\
        --in ${fna_gz} \\
        --out ${meta.id}.prefilter.txt \\
        --threads ${task.cpus} \\
        --min-ident 0.95

    vclust \\
        align \\
        --in ${fna_gz} \\
        --out ${meta.id}.ani.tsv \\
        --filter ${meta.id}.prefilter.txt \\
        --threads ${task.cpus} \\
        --out-ani 0.95 \\
        --out-qcov 0.85

    ### Convert to gani
    csvtk cut \\
        ${meta.id}.ani.tsv \\
        --tabs \\
        --out-tabs \\
        --delete-header \\
        --fields query,reference,gani \\
        --out-file ${meta.id}.gani_new2new.tsv.gz

    ### Compress
    gzip ${meta.id}.ani.tsv

    ### Cleanup
    rm ${meta.id}.prefilter.txt
    """
}
