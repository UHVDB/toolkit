process PILEA_DOWNLOAD {
    tag "pilea"
    label 'process_long'
    storeDir "${params.dbdir}/pilea"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b94c3b34450ee0299ef51e7286457eb7668203471683b50365edb361fd4631b/data' :
        'community.wave.seqera.io/library/pilea:1.3.8--760f05ac95513c7f' }"

    output:
    path("database"), emit: db

    script:
    """
    ### Download pre-built GTDB pilea database
    pilea fetch \\
        -o . \\
        -t ${task.cpus}

    ### Verify required database files
    for f in parameters.tab genomes.tab sketches.pdb; do
        if [ ! -s database/\${f} ]; then
            echo "ERROR: missing database/\${f} after pilea fetch" >&2
            exit 1
        fi
    done
    """

    stub:
    """
    mkdir -p database
    touch database/parameters.tab database/genomes.tab database/sketches.pdb
    """
}
