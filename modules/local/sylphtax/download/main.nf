process SYLPHTAX_DOWNLOAD {
    label 'process_single'
    tag "${params.sylph_taxonomy}"
    storeDir "${params.dbdir}/sylphtax/${params.sylph_taxonomy}"
    publishDir enabled: false

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/48/4882d1faf411b50c4d2feb23bad6858208e9bfd2c11a1b27a554eba01aec3df9/data'
        : 'community.wave.seqera.io/library/unzip_wget:c16e5234983a14dc'}"

    output:
    path("*.tsv.gz"), emit: tsv_gz

    script:
    def taxonomy = params.sylph_taxonomy
    def urls = [
        'GTDB_r214': 'https://zenodo.org/records/14320496/files/gtdb_r214_metadata.tsv.gz',
        'GTDB_r220': 'https://zenodo.org/records/14320496/files/gtdb_r220_metadata.tsv.gz',
        'GTDB_r226': 'https://zenodo.org/records/15314244/files/gtdb_r226_metadata.tsv.gz',
        'GTDB_r232': 'https://zenodo.org/records/19646381/files/gtdb_r232_metadata.tsv.gz'
    ]
    def url = urls[taxonomy]
    if (!url) {
        error "Unknown params.sylph_taxonomy '${taxonomy}'. Supported: ${urls.keySet().join(', ')}"
    }
    def filename = "${taxonomy.toLowerCase()}_metadata.tsv.gz"
    """
    wget -O ${filename} ${url}
    """

    stub:
    def filename = "${params.sylph_taxonomy.toLowerCase()}_metadata.tsv.gz"
    """
    echo "" | gzip > ${filename}
    """
}
