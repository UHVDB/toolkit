process PHAROKKA_PROTEINS {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/67/67572a2cfb490ce391c43e3476def1ea9512701ea93dbf68872af76cbd299ed7/data' :
        'quay.io/biocontainers/pharokka:1.7.5--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(faa_gz)
    path(db)

    output:
    tuple val(meta), path("${meta.id}.pharokka.tsv.gz"), emit: tsv_gz
    tuple val(meta), path("${meta.id}.nohit.faa.gz")   , emit: faa_gz

    script:
    """
    gunzip -c ${faa_gz} > ${meta.id}.faa

    ### Run pharokka
    pharokka_proteins.py \\
        --infile ${meta.id}.faa \\
        --outdir pharokka \\
        --database ${db} \\
        --thread ${task.cpus} \\
        --prefix ${meta.id} \\
        --hmm_only

    ### Extract no-hit proteins
    mv pharokka/*_summary_output.tsv ${meta.id}.pharokka.tsv
    grep "No_PHROGs_HMM" ${meta.id}.pharokka.tsv | cut -f1 > nohit_proteins.txt

    seqkit grep \\
        ${faa_gz} \\
        --pattern-file nohit_proteins.txt \\
        --threads ${task.cpus} \\
        --out-file ${meta.id}.nohit.faa.gz

    ### Compress
    gzip ${meta.id}.pharokka.tsv

    ### Cleanup
    rm -rf pharokka/ ${meta.id}.faa nohit_proteins.txt
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.pharokka.tsv.gz
    echo "" | gzip > ${meta.id}.nohit.faa.gz
    """
}
