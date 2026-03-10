process PHIST_BUILD {
    tag "${meta.id}"
    label "process_super_high"
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/99/99cdbbc8ee707435804fe59e2b78583703a8204b91b88681eb04e4cc1ec8bb23/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-53047a1d197ded34_1?_gl=1*1kuyhwx*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuOTE2NTY5NTQzLjE3NjY0MjU0MjkuMTc2NjQyNTQyOA..

    input:
    tuple val(meta) , path(fna)

    output:
    tuple val(meta) , path("virus.kdb") , emit: kdb
    path(".command.log")                , emit: log
    path(".command.sh")                 , emit: script

    script:
    """
    ### Build kmer-db
    echo "${fna}" > input.list

    kmer-db build \\
        -k 25 \\
        -t ${task.cpus} \\
        -multisample-fasta \\
        input.list \\
        virus.kdb
    """
}
