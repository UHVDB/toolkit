process ICTV_VMRTOFASTA {
    tag "${meta.id}"
    label "process_single"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/75/75e65833e6c52a8d39641b47ff4f6752284b3fc1811bc053ee3835a753850499/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-cb9ca519a948519d_1?_gl=1*786jci*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta), path(xlsx)

    output:
    tuple val(meta), path("${meta.id}.fna.gz")                      , emit: fna_gz
    tuple val(meta), path("processed_accessions_b.fa_names.tsv")    , emit: processed_tsv
    tuple val(meta), path("bad_accessions_b.tsv")                   , emit: bad_tsv
    path(".command.log")                                            , emit: log
    path(".command.sh")                                             , emit: script

    script:
    """
    ### Process VMR
    VMR_to_fasta.py \\
        -mode VMR \\
        -ea B \\
        -VMR_file_name ${xlsx} \\
        -v

    ### Download VMR FNA
    VMR_to_fasta.py \\
        -email ${params.email} \\
        -mode fasta \\
        -ea b \\
        -fasta_dir ./ictv_fastas \\
        -VMR_file_name ${xlsx} \\
        -v

    cat ictv_fastas/*/*.fa > ${meta.id}.fna

    ### Compress
    gzip ${meta.id}.fna

    ### Cleanup
    rm -rf fixed_vmr_b.tsv process_accessions_b.tsv ictv_fastas/
    """
}
