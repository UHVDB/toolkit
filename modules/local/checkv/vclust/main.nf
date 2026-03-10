process CHECKV_VCLUST {
    tag "$meta.id"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/30/3030f14774571b0e1dbacdbd8d12c74e5603d31adef3ac865c0d3af2ed0ad299/data"

    input:
    tuple val(meta) , path(fasta)
    path checkv_db

    output:
    tuple val(meta), path("${meta.id}.novel_checkv.fna.gz") , emit: fna_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    echo "${checkv_db}/genome_db/checkv_reps.fna" > ref_kdb.txt

    ### Build ref DB
    kmer-db \\
        build \\
        -k 25 \\
        -f 0.2 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        ref_kdb.txt \\
        ref.kdb

    echo "${fasta}" > query_kdb.txt

    ### compare query to ref
    kmer-db \\
        new2all \\
        -sparse \\
        -min num-kmers:20 \\
        -min ani-shorter:0.95 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        ref.kdb \\
        query_kdb.txt \\
        query_v_ref.csv

    ### Convert output
    kmer-db \\
        distance \\
        ani-shorter \\
        -sparse \\
        -min 0.95 \\
        -t ${task.cpus} \\
        query_v_ref.csv \\
        query_v_ref.dist.csv

    kmerdb_new2all_to_lzani.py \\
        -i query_v_ref.dist.csv \\
        -o query_v_ref.dist_mod.csv

    cat ${checkv_db}/genome_db/checkv_reps.fna > ref_query.combined.fna
    zcat ${fasta} >> ref_query.combined.fna

    ### Align with LZ-ANI
    lz-ani \\
        all2all \\
        --in-fasta ref_query.combined.fna \\
        -o ${meta.id}.lzani.tsv \\
        --out-format query,reference,ani,qcov,rcov \\
        -t ${task.cpus} \\
        --multisample-fasta true \\
        --out-type tsv \\
        --flt-kmerdb query_v_ref.dist_mod.csv 0.95

    ### Extract new species
    csvtk filter2 \\
        ${meta.id}.lzani.tsv  \\
        --tabs \\
        --filter '( \$ani >= 0.95 ) && ( \$qcov >= 0.85 || \$rcov >= 0.85 )' | \\
    csvtk cut \\
        --tabs \\
        --fields query | \\
    csvtk uniq \\
        --tabs \\
        --out-file ${meta.id}.checkv_matches.tsv

    seqkit grep \\
        ${fasta} \\
        --threads ${task.cpus} \\
        --invert-match \\
        --pattern-file ${meta.id}.checkv_matches.tsv \\
        --out-file ${meta.id}.novel_checkv.fna.gz

    ### Cleanup
    rm ref_kdb.txt query_kdb.txt query_v_ref.csv query_v_ref.dist.csv query_v_ref.dist_mod.csv ref_query.combined.fna ${meta.id}.lzani.tsv ${meta.id}.checkv_matches.tsv
    """
}
