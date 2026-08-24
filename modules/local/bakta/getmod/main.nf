process BAKTA_GETMOD {
    tag "bakta v1.12"
    label 'process_single'
    storeDir "${params.dbdir}/bakta_mod/1.12"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b8a045eec34dae0f3027ab806e8f218a77c5755355480688e500ef644dd5473/data' :
        'community.wave.seqera.io/library/git:2.47.1--hff40a2d_0' }"

    input:
    val(url)

    output:
    path("bakta_mod"), emit: bakta_mod

    script:
    """
    # clone modified bakta repo
    git clone ${url} bakta_mod
    """

    stub:
    """
    mkdir -p bakta_mod/bin
    touch bakta_mod/bin/bakta_proteins
    """
}
