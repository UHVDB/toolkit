process UHVDB_CATNOHEADER {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/54/54481f673ef3b37aa015a39d2ebef5e67d5559a104fee6b741b948e227e7f9b9/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ad38cc6b0f6e1c86_1?_gl=1*1bebhx1*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${publish_dir}"
    
    input:
    tuple val(meta) , path(files, stageAs: 'input_files/*')   , val(suffix)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.${suffix}")  , emit: combined

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
}
