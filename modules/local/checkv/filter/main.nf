process CHECKV_FILTER {
    tag "$meta.id"
    label 'process_low'
    storeDir "${params.outdir}/uhvdb/mine/${meta.source_db.toString().toLowerCase()}/${meta.release}/${meta.id}/checkv_filter/"

    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/caf49df5029a1bfc477ca4ad890c1e001f170511bb584916fa3f572058bf327f/data"

    input:
    tuple val(meta) , path(tsv), path(fasta)

    output:
    tuple val(meta), path("${meta.id}_filtered_checkv.fna.gz")  , emit: fasta
    path "versions.yml"                                         , emit: versions
    path ".command.log"                                         , emit: log
    path ".command.sh"                                          , emit: script

    script:
    def min_completeness= params.min_aai_completeness ?: 50
    def filter1         = '!(( \$completeness_method == "AAI-based (high-confidence)" || \$completeness_method == "AAI-based (medium-confidence)" ) && ( \$completeness <= ' + "${min_completeness}" + ' ) )'
    def filter2         = '( \$kmer_freq <= 1.2 )'
    """
    ### Filter CheckV results to remove obvious non-viruses
    csvtk filter2 \\
        ${tsv} \\
        --tabs \\
        --filter '${filter1} && ${filter2}' \\
        --num-cpus ${task.cpus} \\
    | csvtk cut --tabs \\
        --fields "contig_id" \\
        --out-file ${meta.id}_filtered_checkv.txt

    seqkit grep \\
        ${fasta} \\
        --threads ${task.cpus} \\
        --pattern-file ${meta.id}_filtered_checkv.txt \\
        --out-file ${meta.id}_filtered_checkv.fna.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
