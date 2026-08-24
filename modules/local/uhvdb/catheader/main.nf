process UHVDB_CATHEADER {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/54/54481f673ef3b37aa015a39d2ebef5e67d5559a104fee6b741b948e227e7f9b9/data' :
        'community.wave.seqera.io/library/pigz:2.8--1805fb77a8973445' }"

    input:
    tuple val(meta), path(files, stageAs: 'input_files/*'), val(lines_per_header), val(suffix)

    output:
    tuple val(meta), path("${meta.id}.${suffix}"), emit: combined

    script:
    def compression_cmd = suffix.endsWith('gz') ? "pigz" : suffix.endsWith('zst') ? "zstd --rm" : 'xz'
    """
    ### Print header line
    for file in input_files/*; do
        zcat \$file | head -n ${lines_per_header} >> ${meta.id}.${suffix.split('\\.')[0]} || [ \${PIPESTATUS[0]} -eq 0 -o \${PIPESTATUS[0]} -eq 141 ]
        break
    done

    ### Print non-header lines
    for file in input_files/*; do
        if [ \$(zcat \$file | wc -l) -gt ${lines_per_header} ]; then
            zcat \$file | tail -n +${lines_per_header + 1} >> ${meta.id}.${suffix.split('\\.')[0]}
        else
            echo "File \$file has only header line or is empty; skipping content append."
        fi
    done

    ### Compress
    ${compression_cmd} ${meta.id}.${suffix.split('\\.')[0]}
    """

    stub:
    """
    echo "" | gzip > ${meta.id}.${suffix}
    """
}
