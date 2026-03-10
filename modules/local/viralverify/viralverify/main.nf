process VIRALVERIFY_VIRALVERIFY {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/78/78f1fdad1da31673da6d364620354c28b3f18d792ddce78866219ef484e87db4/data"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    tuple val(meta), path ("${meta.id}_viralverify.csv.gz") , emit: csv_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Uncompres
    gunzip -c ${fasta} > ${meta.id}.fasta

    ### Run ViralVerify
    ${projectDir}/scripts/viralVerify/bin/viralverify \\
        -f ${meta.id}.fasta \\
        --hmm ${db} \\
        -o ${meta.id}_viralverify \\
        -t ${task.cpus}

    ### Compress
    mv ${meta.id}_viralverify/${file(meta.id + ".fasta").getBaseName()}_result_table.csv ${meta.id}_viralverify.csv
    gzip -c ${meta.id}_viralverify.csv > ${meta.id}_viralverify.csv.gz

    ### Cleanup
    rm -rf ${meta.id}.fasta ${meta.id}_viralverify
    """
}
