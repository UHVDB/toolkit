process INTERPROSCAN_INTERPROSCAN {
    tag "${meta.id}"
    label 'process_super_high'
    container "quay.io/microbiome-informatics/interproscan:5.74-105.0"
    containerOptions "--bind ${db}/data:/opt/interproscan/data"

    input:
    tuple val(meta) , path(faa_gz)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.interproscan.tsv.gz") , emit: tsv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    """
    ### Decompress
    gunzip -c -f ${faa_gz} > ${faa_gz.getBaseName()}
    # replace all '*' characters to avoid InterProScan errors
    sed -i 's/*//g' ${faa_gz.getBaseName()}

    ### Run InterProScan
    export JAVA_TOOL_OPTIONS="-Dfile.encoding=UTF-8"

    bash ./${db}/interproscan.sh \\
        -cpu ${task.cpus} \\
        -dp \\
        --goterms \\
        --input ${faa_gz.getBaseName()} \\
        --output-file-base ${meta.id}.interproscan

    ### Compress
    gzip ${meta.id}.interproscan.tsv

    ### Cleanup
    rm -rf ${meta.id}.interproscan.xml ${meta.id}.interproscan.json ${meta.id}.interproscan.gff3 \\
        ${faa_gz.getBaseName()} temp
    """
}
