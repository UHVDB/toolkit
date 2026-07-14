process UHVDB_REPGRAPH {
    tag "${meta.id}"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/c2/c294e0026b39f8f08f779c442c998417549255edc252e45132701fd9f36a06cf/data':
        'community.wave.seqera.io/library/seqkit_polars:d8092df540cb603a' }"

    input:
    tuple val(meta) , path(gani_gz)
    tuple val(meta2), path(new_fna_gz) , path(old_fna_gz)

    output:
    tuple val(meta), path("*.gani.tsv.gz")   , emit: tsv_gz
    tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    tuple val("${task.process}"), val('uhvdb_repgraph'), eval('uhvdb_repgraph.py --version'), topic: versions, emit: versions_uhvdb_repgraph

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    ### Extract IDs of all sequences
    zgrep "^>" ${new_fna_gz} | sed 's/^>//' > ${prefix}.ids.txt
    zgrep "^>" ${old_fna_gz} | sed 's/^>//' >> ${prefix}.ids.txt

    ### Extract subgraph of GANI graph that includes only sequences in the fasta files
    uhvdb_repgraph.py \\
        --input_ids ${prefix}.ids.txt \\
        --input_graph ${gani_gz} \\
        --output_graph ${prefix}.gani.tsv
    
    ### Compress output graph
    gzip ${prefix}.gani.tsv

    ### Cleanup
    rm ${prefix}.ids.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}.gani.tsv.gz
    """
}
