process GENOMAD_HMMSEARCH {
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/62/620c1a5f8fd040e4573e4917b8e54709914532c688ce4c0f3e73d5331c461068/data'
        : 'community.wave.seqera.io/library/hmmer_pyrodigal-gv_biopython_polars:2e0f191a54fa7bea'}"

    input:
    tuple val(meta), path(fna_gz)
    path hmm
    path tsv_gz

    output:
    tuple val(meta), path("*.hcfilter.fna.gz")  , emit: fna_gz
    tuple val(meta), path("*.hcfilter.tsv.gz")            , emit: tsv_gz

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Predict genes
    pyrodigal-gv \\
        -i ${fna_gz} \\
        -a ${prefix}.pyrodigalgv.faa \\
        --jobs ${task.cpus} &> /dev/null

    ### Run hmmsearch
    hmmsearch --noali \\
        -o /dev/null \\
        -E 1e-5 \\
        --tblout ${prefix}_v_genomad_hallmarks.tbl \\
        --cpu ${task.cpus} \\
        ${hmm} \\
        ${prefix}.pyrodigalgv.faa \\
        2> hmmsearch.log

    ### Identify confident viruses
    uhvdb_hcfilter.py \\
        --hmmsearch_tbl ${prefix}_v_genomad_hallmarks.tbl \\
        --genomad_tsv ${tsv_gz} \\
        --fasta ${fna_gz} \\
        --output_tsv ${prefix}.hcfilter.tsv \\
        --output_fasta ${prefix}.hcfilter.fna
    
    gzip ${prefix}.hcfilter.tsv ${prefix}.hcfilter.fna

    ### Cleanup
    rm -rf ${prefix}.pyrodigalgv.faa ${prefix}_v_genomad_hallmarks.tbl
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.hcfilter.tsv.gz
    echo "" | gzip > ${prefix}.hcfilter.fna.gz
    """
}
