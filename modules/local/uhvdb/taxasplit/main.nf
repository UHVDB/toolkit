process UHVDB_TAXASPLIT {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/05/052a2a9822f7f61d1130ead55fc072b6502fbe287a929e3dcb7153fc9e7b69eb/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-416fa8571eb967e5_1?_gl=1*1rfsze2*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.
    storeDir "${params.output_dir}/${params.new_release_id}_outputs/taxasplit/"

    input:
    tuple val(meta) , path(fna_gz)
    tuple val(meta2), path(tsv_gz)

    output:
    tuple val(meta), path("${meta.id}.taxa*.fna.gz")   , emit: fna_gzs

    script:
    """
    ### Split fasta by taxa
    taxa_split.py \\
        --input ${tsv_gz} \\
        --output ${meta.id} \\
        --rank Class
    
    for file in ${meta.id}_taxa*.tsv; do
        taxa="\${file#${meta.id}_taxa}"
        taxa="\${taxa%.tsv}"

        seqkit grep \\
            ${fna_gz} \\
            --pattern-file \${file} \\
            --out-file ${meta.id}.taxa\${taxa}.fna.gz
    done

    ### Cleanup
    rm -f ${meta.id}_taxa*.tsv
    """
}
