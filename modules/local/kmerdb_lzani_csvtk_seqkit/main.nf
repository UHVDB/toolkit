process KMERDB_LZANI_CSVTK_SEQKIT {
    tag "${meta.id}"
    label 'process_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/96/96013f9da7669b6e3bcbc6eaa5e350df65ce635eb26af9e1b0bfd164a592b6ac/data'
        : 'community.wave.seqera.io/library/kmer-db_lz-ani_seqkit_csvtk_python:7922d65ae24d9f78'}"

    input:
    tuple val(meta), path(query_fasta)
    tuple val(meta2), path(ref_fasta)

    output:
    tuple val(meta), path("*.novel_checkv.fna.gz")        , emit: fna_gz
    tuple val(meta), path("*.lzani.tsv.gz")        , emit: tsv_gz
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions
    // TODO: Add kmer-db and lz-ani versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def args3 = task.ext.args3 ?: ''
    def args4 = task.ext.args4 ?: ''
    def args5 = task.ext.args5 ?: ''
    """
    ### Build reference database
    echo "${ref_fasta}" > ref_kdb.txt

    kmer-db \\
        build \\
        ${args} \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        ref_kdb.txt \\
        ref.kdb

    ### compare query to ref
    echo "${query_fasta}" > query_kdb.txt

    kmer-db \\
        new2all \\
        -sparse \\
        ${args2} \\
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
        ${args3} \\
        -t ${task.cpus} \\
        query_v_ref.csv \\
        query_v_ref.dist.csv

    kmerdb_to_lzani.py \\
        -i query_v_ref.dist.csv \\
        -o query_v_ref.dist_mod.csv

    cat ${ref_fasta} > ref_query.combined.fna
    zcat ${query_fasta} >> ref_query.combined.fna

    ### Align with LZ-ANI
    lz-ani \\
        all2all \\
        --in-fasta ref_query.combined.fna \\
        -o ${prefix}.lzani.tsv \\
        --out-format query,reference,ani,qcov,rcov \\
        -t ${task.cpus} \\
        --multisample-fasta true \\
        --out-type tsv \\
        --flt-kmerdb query_v_ref.dist_mod.csv ${args4}

    gzip -c ${prefix}.lzani.tsv > ${prefix}.lzani.tsv.gz

    ### Extract new species
    csvtk filter2 \\
        ${prefix}.lzani.tsv  \\
        --tabs \\
        ${args5} | \\
    csvtk cut \\
        --tabs \\
        --fields query | \\
    csvtk uniq \\
        --tabs \\
        --out-file ${prefix}.checkv_matches.tsv

    seqkit grep \\
        ${query_fasta} \\
        --threads ${task.cpus} \\
        --invert-match \\
        --pattern-file ${prefix}.checkv_matches.tsv \\
        --out-file ${prefix}.novel_checkv.fna.gz

    ### Cleanup
    rm ref_kdb.txt query_kdb.txt query_v_ref.csv query_v_ref.dist.csv \\
        query_v_ref.dist_mod.csv ref_query.combined.fna ${prefix}.lzani.tsv ${prefix}.checkv_matches.tsv
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.novel_checkv.fna.gz
    echo "" | gzip > ${prefix}.lzani.tsv.gz
    """
}
