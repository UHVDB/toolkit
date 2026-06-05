process ICTV_VMRTOFASTA {
    tag "${meta.id}"
    label "process_single"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/biopython_numpy_pandas:e83f56be8db6273e':
        'community.wave.seqera.io/library/biopython_numpy_pandas:db7e5435dc35f4b8' }"

    input:
    tuple val(meta), path(xlsx)

    output:
    tuple val(meta), path("${meta.id}.fna.gz")                      , emit: fna_gz
    tuple val(meta), path("processed_accessions_b.fa_names.tsv")    , emit: processed_tsv
    tuple val(meta), path("bad_accessions_b.tsv")                   , emit: bad_tsv
    tuple val("${task.process}"), val('VMR_to_fasta'), eval('VMR_to_fasta.py --version'), topic: versions, emit: versions_VMR_to_fasta


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
