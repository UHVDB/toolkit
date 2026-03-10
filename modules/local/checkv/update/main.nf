process CHECKV_UPDATE {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e9/e9e68b8189c2bf3b433b6ed9de5c59335e4b546b870f8ecaf60ad301c89fc660/data"
    storeDir "${params.output_dir}/uhvdb_${params.new_release_id}/checkv_db/"

    input:
    tuple val(meta), path(fasta)
    path db

    output:
    path "checkv_db_${params.new_release_id}"   , emit: checkv_db
    path ".command.log"                         , emit: log
    path ".command.sh"                          , emit: script

    script:
    """
    ### Decompress
    gzip -c -d ${fasta} > new_checkv_genomes.fna

    ### Update CheckV database
    checkv \\
        update_database \\
        ${db} \\
        checkv_db_${params.new_release_id} \\
        new_checkv_genomes.fna \\
        --threads ${task.cpus}

    diamond makedb \\
        --in checkv_db_${params.new_release_id}/genome_db/checkv_reps.faa \\
        --db checkv_db_${params.new_release_id}/genome_db/checkv_reps.dmnd \\
        --threads ${task.cpus}

    ### Cleanup
    rm new_checkv_genomes.fna
    """
}
