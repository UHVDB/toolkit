process BACPHLIP {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/2c/2c527b78d922f59ba27a41a385d3728a34a8dc0d059723a0931d8fef2a83d404/data' :
        'community.wave.seqera.io/library/bacphlip_hmmer_numpy:9fcb204e214b3608' }"

    input:
    tuple val(meta), path(fna_gz)

    output:
    tuple val(meta), path("${meta.id}.bacphlip.tsv.gz"), emit: tsv_gz

    script:
    """
    ### Decompress
    gunzip -c ${fna_gz} > ${meta.id}.fna

    num_seqs=\$(grep -c "^>" ${meta.id}.fna)
    if [ "\$num_seqs" -gt 1 ]; then
        multi_flag="--multi_fasta"
    else
        multi_flag=""
    fi

    ### Run BACPHLIP
    bacphlip \\
        --input_file ${meta.id}.fna \\
        --force_overwrite \\
        \${multi_flag} \\

    ### Compress
    mv ${meta.id}.fna.bacphlip ${meta.id}.bacphlip.tsv
    gzip ${meta.id}.bacphlip.tsv

    ### Cleanup
    rm -rf ${meta.id} ${meta.id}.BACPHLIP_DIR/ ${meta.id}.hmmsearch.tsv ${meta.id}.fna
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.bacphlip.tsv.gz
    """
}
