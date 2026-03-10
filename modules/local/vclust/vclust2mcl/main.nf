process VCLUST_VCLUST2MCL {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/ca/caf49df5029a1bfc477ca4ad890c1e001f170511bb584916fa3f572058bf327f/data"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("${meta.id}.vclust_mcl.tsv")  , emit: tsv
    path "versions.yml"                                 , emit: versions
    path ".command.log"                                 , emit: log
    path ".command.sh"                                  , emit: script

    script:
    """
    ls *.tsv.gz > input_files.txt

    csvtk concat \\
        --tabs \\
        --no-header-row \\
        --infile-list input_files.txt \\
        --num-cpus ${task.cpus} | \\
    csvtk cut \\
        --fields 1,2,3 \\
        --num-cpus ${task.cpus} \\
        --tabs \\
        --out-file ${meta.id}.vclust_mcl.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        csvtk: \$(echo \$( csvtk version | sed -e "s/csvtk v//g" ))
        seqkit: \$( seqkit version | sed 's/seqkit v//' )
    END_VERSIONS
    """
}
