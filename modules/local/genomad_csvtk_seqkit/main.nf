process GENOMAD_CSVTK_SEQKIT {
    tag "${meta.id}"
    label 'process_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8e/8ebf1ebcc0beb6209556c55bf8fb291c8781b19ed3bc820cc69ad8bfba16b752/data'
        : 'community.wave.seqera.io/library/genomad_seqkit_aria2_csvtk:61faae14dee3888a'}"

    input:
    tuple val(meta), path(fasta)
    path(genomad_db)

    output:
    tuple val(meta), path("*_virus.fna.gz")        , emit: fna_gz
    tuple val(meta), path("*_virus_summary.tsv.gz"), emit: summary_tsv_gz
    tuple val(meta), path("*_virus_genes.tsv.gz")  , emit: genes_tsv_gz
    tuple val("${task.process}"), val('genomad'), eval("genomad --version 2>&1 | sed 's/^.*geNomad, version //; s/ .*//'"), topic: versions, emit: versions_genomad
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    """
    ### Run geNomad
    genomad \\
        end-to-end \\
        ${fasta} \\
        genomad_results \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        ${args}

    ### Save virus outputs
    gzip -c genomad_results/*_summary/*_virus_summary.tsv > ${prefix}_virus_summary.tsv.gz
    gzip -c genomad_results/*_summary/*_virus_genes.tsv > ${prefix}_virus_genes.tsv.gz

    ### Remove LQ
    csvtk filter2 \\
        ${prefix}_virus_summary.tsv.gz \\
        --num-cpus ${task.cpus} \\
        ${args2} \\
        --out-file ${prefix}_filtered_genomad.txt

    seqkit grep \\
        genomad_results/*_summary/*_virus.fna \\
        --threads ${task.cpus} \\
        --pattern-file ${prefix}_filtered_genomad.txt \\
        --out-file ${prefix}_virus.fna.gz

    ### Cleanup
    rm -rf tmp/ genomad_results/ combined_filtered.fasta.gz ${prefix}_filtered_genomad.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}_virus.fna.gz
    echo "" | gzip > ${prefix}_virus_summary.tsv.gz
    echo "" | gzip > ${prefix}_virus_genes.tsv.gz
    """
}
