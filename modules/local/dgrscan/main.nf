process DGRSCAN {
    tag "${meta.id}"
    label 'process_long'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/74/744871b576856f37a45c5d005427d288b5c8e3679ad458dafcea227df6d703d8/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-99f002d7dee1722f_1?_gl=1*1ktke68*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTg0OTY4ODYzMC4xNzY1NDA0Njk5LjE3NjU0MDQ2OTk.

    input:
    tuple val(meta) , path(fna)

    output:
    tuple val(meta) , path("${meta.id}.dgrscan.txt.gz") , emit: txt_gz
    path(".command.log")                                , emit: log
    path(".command.sh")                                 , emit: script

    script:
    """
    ### Decompress
    gunzip -f -c ${fna} > ${fna.getBaseName()}

    ### Run DGRscan
    DGRscan.py \\
        -inseq ${fna.getBaseName()} \\
        -summary ${meta.id}.dgrscan.txt

    touch ${meta.id}.dgrscan.txt

    ### Compress
    gzip -f ${meta.id}.dgrscan.txt

    ### Cleanup
    rm -f ${fna.getBaseName()}
    """
}
