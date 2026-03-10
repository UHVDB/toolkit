process UHVDB_UNCERTAIN {
    tag "$meta.id"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/caf49df5029a1bfc477ca4ad890c1e001f170511bb584916fa3f572058bf327f/data"

    input:
    tuple val(meta) , path(fna_gz), path(tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.uncertain.fna.gz")    , emit: uncertain_fna_gz
    tuple val(meta), path("${meta.id}.certain.fna.gz")      , emit: certain_fna_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    def filter1         = '( \$uhvdb_virus_classification == "uncertain" )'
    def filter2         = '( \$contig_length >= 10000 )'
    """
    ### Extract uncertain viruses
    csvtk filter2 \\
        ${tsv_gz} \\
        --tabs \\
        --filter '${filter1} && ${filter2}' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields seq_name \\
        --out-file ${meta.id}.uncertain_viruses.txt

    seqkit grep \\
        ${fna_gz} \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}.uncertain_viruses.txt \\
        --out-file ${meta.id}.uncertain.fna.gz

    ### Extract certain viruses
    seqkit grep \\
        ${fna_gz} \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}.uncertain_viruses.txt \\
        --invert-match \\
        --out-file ${meta.id}.certain.fna.gz

    ### Cleanup
    rm ${meta.id}.uncertain_viruses.txt
    """
}
