process UHVDB_GCODESPLIT {
    tag "${meta.id}"
    label 'process_high_mem'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/05/052a2a9822f7f61d1130ead55fc072b6502fbe287a929e3dcb7153fc9e7b69eb/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-416fa8571eb967e5_1?_gl=1*1rfsze2*_gcl_au*NTUzODYxMTI2LjE3Njc2NTE5OTY.

    input:
    tuple val(meta) , path(fna_gz)
    tuple val(meta2), path(tsv_gz)

    output:
    tuple val(meta), path("${meta.id}_gcode*.fna.gz")   , emit: fna_gzs
    path ".command.log"                                 , emit: log
    path ".command.sh"                                  , emit: script

    script:
    """
    ### Split by genetic code
    genetic_code_split.py \\
        --input ${tsv_gz} \\
        --output ${meta.id}
    
    for file in ${meta.id}_gcode*.tsv; do
        code=\$(echo \${file} | sed -E 's/.*_gcode([0-9]+).tsv/\\1/')

        seqkit grep \\
            ${fna_gz} \\
            --pattern-file \${file} \\
            --out-file ${meta.id}_gcode\${code}.fna.gz

        if [ \$(zgrep -c "^>" "${meta.id}_gcode\${code}.fna.gz") -eq 0 ]; then
            rm -f ${meta.id}_gcode\${code}.fna.gz
        fi
    done

    ### Cleanup
    rm -f ${meta.id}_gcode*.tsv
    """
}
