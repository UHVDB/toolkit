process VCLUST_NEW2ALL {
    tag "${meta.id}"
    label 'process_super_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/57/5710ab5109e6a457b62b6094f75149b836676c357cc46503f613d285146fa18d/data"

    input:
    tuple val(meta) , path(query), path(ref)

    output:
    tuple val(meta), path("${meta.id}.ani.tsv.gz")          , emit: ani_gz
    tuple val(meta), path("${meta.id}.gani_new2all.tsv.gz") , emit: gani_gz
    path ".command.log"                                     , emit: log
    path ".command.sh"                                      , emit: script

    script:
    """
    ### Build kmer-db database for reference
    echo "${ref}" > ref_kdb.txt
    
    kmer-db \\
        build \\
        -k 25 \\
        -f 0.2 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        ref_kdb.txt \\
        ref.kdb

    echo "${query}" > query_kdb.txt

    ### Compare query to reference
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

    ### Convert kmer-db output to LZ-ANI filter format
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
        -o ${meta.id}.vclust_prefilter.txt

    ### Align sequences with LZ-ANI
    lz-ani \\
        all2all \\
        --in-fasta ${ref} \\
        -o ${meta.id}.ani.tsv \\
        --out-format query,reference,gani,ani,qcov,rcov \\
        -t ${task.cpus} \\
        --multisample-fasta true \\
        --out-type tsv \\
        --out-filter ani 0.95 \\
        --out-filter qcov 0.85 \\
        --flt-kmerdb ${meta.id}.vclust_prefilter.txt 0.95

    gzip ${meta.id}.ani.tsv

    ### Extract gANIs
    csvtk cut \\
        ${meta.id}.ani.tsv.gz \\
        --tabs \\
        --out-tabs \\
        --delete-header \\
        --fields query,reference,gani \\
        --out-file ${meta.id}.gani_new2all.tsv.gz

    ### Cleanup
    rm -rf ref_kdb.txt query_kdb.txt query_v_ref.csv query_v_ref.dist.csv ${meta.id}.vclust_prefilter.txt
    """
}
