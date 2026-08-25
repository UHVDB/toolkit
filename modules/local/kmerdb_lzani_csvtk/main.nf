process KMERDB_LZANI_CSVTK {
    tag "${meta.id}"
    label 'process_super_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/96/96013f9da7669b6e3bcbc6eaa5e350df65ce635eb26af9e1b0bfd164a592b6ac/data'
        : 'community.wave.seqera.io/library/kmer-db_lz-ani_seqkit_csvtk_python:7922d65ae24d9f78'}"

    input:
    tuple val(meta), path(query_fasta)
    tuple val(meta2), path(ref_fasta)
    val min_ani
    val min_qcov

    output:
    tuple val(meta), path("*.lzani.tsv.gz") , emit: lzani_tsv_gz
    tuple val(meta), path("*.gani.tsv.gz")  , emit: gani_tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}.new2old"
    """
    ### Build reference database
    echo "${ref_fasta}" >| ref_kdb.txt

    kmer-db \\
        build \\
        -k 25 -f 0.2 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        ref_kdb.txt \\
        ref.kdb

    ### compare query to ref
    echo "${query_fasta}" >| query_kdb.txt

    kmer-db \\
        new2all \\
        -sparse \\
        -min num-kmers:20 -min ani-shorter:${min_ani} \\
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
        -min ${min_ani} \\
        -t ${task.cpus} \\
        query_v_ref.csv \\
        query_v_ref.dist.csv

    kmerdb_to_lzani.py \\
        -i query_v_ref.dist.csv \\
        -o query_v_ref.dist_mod.csv

    zcat ${ref_fasta} >| ref_query.combined.fna
    zcat ${query_fasta} >> ref_query.combined.fna

    ### Align with LZ-ANI
    lz-ani \\
        all2all \\
        --in-fasta ref_query.combined.fna \\
        -o ${prefix}.lzani.tsv \\
        -t ${task.cpus} \\
        --multisample-fasta true \\
        --out-type tsv \\
        --flt-kmerdb query_v_ref.dist_mod.csv ${min_ani} \\
        --out-filter ani ${min_ani} \\
        --out-filter qcov ${min_qcov}

    gzip -c ${prefix}.lzani.tsv >| ${prefix}.lzani.tsv.gz

    ### Extract new species
    csvtk cut \\
        ${prefix}.lzani.tsv \\
        --tabs \\
        --delete-header \\
        --fields query,reference,gani \\
        --out-file ${prefix}.gani.tsv.gz

    ### Cleanup
    rm ref_kdb.txt query_kdb.txt query_v_ref.csv query_v_ref.dist.csv \\
        query_v_ref.dist_mod.csv ref_query.combined.fna ${prefix}.lzani.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.new2old"
    """
    echo "" | gzip >  ${prefix}.lzani.tsv.gz
    echo "" | gzip >  ${prefix}.gani.tsv.gz
    """
}
