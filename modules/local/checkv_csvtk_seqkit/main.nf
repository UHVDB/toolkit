process CHECKV_SEQKIT_CSVTK_SEQKIT {
    tag "${meta.id}"
    label 'process_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8c/8c6aec9a6aa3550e56eea135dd9923e85c47e2d64ba7a947d21336efad7bf65e/data'
        : 'community.wave.seqera.io/library/checkv_seqkit_csvtk:2cdd52311c7ea5ff'}"

    input:
    tuple val(meta), path(fasta)
    path(checkv_db)

    output:
    tuple val(meta), path("*_viruses.fna.gz")          , emit: fna_gz
    tuple val(meta), path("*_quality_summary.tsv.gz")  , emit: summary_tsv_gz
    tuple val("${task.process}"), val("checkv"), eval("checkv -h 2>&1 | sed '1!d;s/^.*CheckV v//;s/:.*//'"), topic: versions, emit: versions_checkv
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    """
    ### Run CheckV
    checkv \\
        end_to_end \\
        ${args} \\
        -t ${task.cpus} \\
        -d ${checkv_db} \\
        ${fasta} \\
        ${prefix}

    gzip -c ${prefix}/quality_summary.tsv > ${prefix}_quality_summary.tsv.gz

    ### Fix provirus headers
    seqkit replace \\
        ${prefix}/proviruses.fna \\
        --pattern "(_\\d\\s.*)" \\
        --replacement "" \\
        --threads ${task.cpus} \\
        --out-file ${prefix}_proviruses_fix.fna

    cat ${prefix}_proviruses_fix.fna ${prefix}/viruses.fna > ${prefix}.viruses.fna

    ### Remove LQ
    csvtk filter2 \\
        ${prefix}/completeness.tsv \\
        --num-cpus ${task.cpus} \\
        ${args2} \\
        --out-file ${prefix}_filtered_checkv.txt

    seqkit grep \\
        ${prefix}.viruses.fna \\
        --threads ${task.cpus} \\
        --pattern-file ${prefix}_filtered_checkv.txt \\
        --out-file ${prefix}_viruses.fna.gz

    ### Cleanup
    rm -rf ${prefix} ${prefix}_proviruses_fix.fna ${prefix}/ ${prefix}.viruses.fna \\
        ${prefix}_completeness.tsv.gz ${prefix}_contamination.tsv.gz ${prefix}_complete_genomes.tsv.gz \\
        ${prefix}_filtered_checkv.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}_viruses.fna.gz
    echo "" | gzip > ${prefix}_quality_summary.tsv.gz
    """
}
