process UHVDB_CATNOHEADER {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/54/54481f673ef3b37aa015a39d2ebef5e67d5559a104fee6b741b948e227e7f9b9/data' :
        'community.wave.seqera.io/library/pigz:2.8--1805fb77a8973445' }"

    input:
    tuple val(meta), path(files, stageAs: 'input_files/*'), val(suffix)

    output:
    tuple val(meta), path("${meta.id}.${suffix}"), emit: combined

    script:
    def compression_cmd = suffix.endsWith('gz') ? 'pigz' : suffix.endsWith('zst') ? "zstd --rm" : 'xz'
    """
    ### Combine files ###
    for file in input_files/*; do
        if [[ \$file == *.gz ]]; then
            zcat \$file >> ${meta.id}.${suffix.split('\\.')[0]}
        else
            cat \$file >> ${meta.id}.${suffix.split('\\.')[0]}
        fi
    done

    ${compression_cmd} ${meta.id}.${suffix.split('\\.')[0]}
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.${suffix}
    """
}
