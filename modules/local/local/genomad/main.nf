process LOCAL_GENOMAD {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/0c/0c39703d881069a69d14e68d12258fd1a93f2a9bd17870f6f6ab39a6b63e094f/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-30e54ab816eb9c63_1?_gl=1*9mafpw*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1

    input:
    tuple val(meta), val(fasta)
    path(genomad_db)

    output:
    tuple val(meta), path("${meta.id}_virus.fna.gz")        , emit: fna_gz
    tuple val(meta), path("${meta.id}_virus_summary.tsv.gz"), emit: summary_tsv_gz
    tuple val(meta), path("${meta.id}_virus_genes.tsv.gz")  , emit: genes_tsv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    def filter1         = '( ( \$virus_score >= 0.7 && \$length >= 2000 ) || ( \$taxonomy =~ "Inoviridae" ) )'
    def filter2         = '!( \$taxonomy =~ "Caudoviricetes" && \$length < 10000 )'
    def filter3         = '!( \$taxonomy =~ "Inoviridae" && ( \$length < 4500 || \$length > 12500 ) )'
    def filter4         = '!( \$taxonomy == "Unclassified" )'
    def filter5         = '( ( \$taxonomy =~ "viricetes" ) || ( \$taxonomy =~ "Anelloviridae" ) )'
    """
    ### Run geNomad
    genomad \\
        end-to-end \\
        ${fasta} \\
        genomad_results \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        --splits 5 --relaxed

    ### Save virus outputs
    gzip -c genomad_results/*_summary/*_virus_summary.tsv > ${meta.id}_virus_summary.tsv.gz
    gzip -c genomad_results/*_summary/*_virus_genes.tsv > ${meta.id}_virus_genes.tsv.gz

    ### Remove LQ
    csvtk filter2 \\
        ${meta.id}_virus_summary.tsv.gz \\
        --tabs \\
        --filter '${filter1} && ${filter2} && ${filter3} && ${filter4} && ${filter5}' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields "seq_name" \\
        --out-file ${meta.id}_filtered_genomad.txt

    seqkit grep \\
        genomad_results/*_summary/*_virus.fna \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}_filtered_genomad.txt \\
        --out-file ${meta.id}_virus.fna.gz

    ### Cleanup
    rm -rf genomad_results/ ${meta.id}_filtered_genomad.txt
    """
}
