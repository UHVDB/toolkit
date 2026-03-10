process DEACON_INDEXFETCH {
    tag "deacon v0.13.2"
    label 'process_single'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e2/e2bc1e94834d132c6d67b966efbd722e240ffc802187944e739f761a94124ed9/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-e9a85263ce475576_1?_gl=1*zvfk8*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTU1NzczMTA4LjE3NjYxNzI5NzguMTc2NjE3Mjk3OA..
    storeDir "${params.db_dir}/deacon/0.13.2"

    output:
    path("panhuman-1.k31w15.idx")   , emit: index
    path(".command.log")            , emit: log
    path(".command.sh")             , emit: script

    script:
    """
    deacon index \\
        fetch \\
        panhuman-1
    """
}
