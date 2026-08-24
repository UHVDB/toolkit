process VFDB_DOWNLOAD {
    tag "VFDB 2026_03"
    label 'process_medium'
    storeDir "${params.dbdir}/vfdb/2026_03"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/e8/e8cd0c84fc74d2b010f1cf3061e9b1b1ffb1415522a4dbff42b3a93150461b3a/data' :
        'quay.io/biocontainers/diamond:2.1.11--h5ca1c30_0' }"

    output:
    path("VFDB.dmnd"), emit: dmnd

    script:
    """
    ### Download VFDB proteins
    wget https://www.mgc.ac.cn/VFs/Down/VFDB_setB_pro.fas.gz

    ### Create DIAMOND database
    diamond \\
        makedb \\
        --threads ${task.cpus} \\
        --in VFDB_setB_pro.fas.gz \\
        -d VFDB

    ### Cleanup
    rm -rf VFDB_setB_pro.fas.gz
    """

    stub:
    """
    touch VFDB.dmnd
    """
}
