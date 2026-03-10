process CHECKV_ENDTOEND {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ed/eda5d14cc74e9df5c23ea0fa0d5126d63438792c770b3485a6dfeaa4e6171778/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-fb2c59f3624cccf3_1?_gl=1*io0i31*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path("${meta.id}_completeness.tsv.gz")     , emit: completeness_tsv_gz
    tuple val(meta), path("${meta.id}_contamination.tsv.gz")    , emit: contamination_tsv_gz
    tuple val(meta), path("${meta.id}_complete_genomes.tsv.gz") , emit: complete_genomes_tsv_gz , optional: true
    tuple val(meta), path("${meta.id}_viruses.fna.gz")          , emit: virus_fna_gz
    tuple val(meta), path("${meta.id}_quality_summary.tsv.gz")  , emit: quality_summary_tsv_gz  , optional: true
    path ".command.log"                                         , emit: log
    path ".command.sh"                                          , emit: script

    script:
    def filter1         = '( \$aai_completeness >= 50 )'
    def filter2         = '( \$kmer_freq <= 1.2 )'
    def filter3         = '( \$contig_length / \$aai_expected_length <= 1.5 )'
    """
    ### Run CheckV
    checkv \\
        end_to_end \\
        -t ${task.cpus} \\
        -d ${db} \\
        ${fasta} \\
        ${meta.id}

    ### Save outputs
    gzip -c ${meta.id}/quality_summary.tsv > ${meta.id}_quality_summary.tsv.gz
    gzip -c ${meta.id}/completeness.tsv > ${meta.id}_completeness.tsv.gz
    gzip -c ${meta.id}/contamination.tsv > ${meta.id}_contamination.tsv.gz
    gzip -c ${meta.id}/complete_genomes.tsv > ${meta.id}_complete_genomes.tsv.gz

    ### Fix provirus headers
    seqkit replace \\
        ${meta.id}/proviruses.fna \\
        --pattern "(_\\d\\s.*)" \\
        --replacement "" \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}_proviruses_fix.fna

    cat ${meta.id}_proviruses_fix.fna ${meta.id}/viruses.fna > ${meta.id}.viruses.fna
    gzip ${meta.id}.viruses.fna

    ### Remove LQ
    csvtk filter2 \\
        ${meta.id}_completeness.tsv.gz \\
        --tabs \\
        --filter '${filter1} && ${filter2} && ${filter3}' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields "contig_id" \\
        --out-file ${meta.id}_filtered_checkv.txt

    seqkit grep \\
        ${meta.id}.viruses.fna.gz \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}_filtered_checkv.txt \\
        --out-file ${meta.id}_viruses.fna.gz

    ### Cleanup
    rm -rf ${meta.id} ${meta.id}_proviruses_fix.fna ${meta.id}/
    """
}
