process UHVDB_GENECOVERAGE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/b8/b80c0153f3740c99d626acdb271cc7c62e220ff17d8f8421493aa6365c08038e/data':
        'community.wave.seqera.io/library/pysam_numpy_polars:ffb596c8bdfe2ed8' }"

    input:
    tuple val(meta), path(bam)
    path(annotations_tsv_gz)

    output:
    tuple val(meta), path("*.gene_coverage.tsv.gz"), emit: tsv_gz
    // tuple val("${task.process}"), val('numpy'), eval('python -c "import numpy; print(numpy.__version__)"'), topic: versions, emit: versions_numpy
    // tuple val("${task.process}"), val('polars'), eval('python -c "import polars; print(polars.__version__)"'), topic: versions, emit: versions_polars
    // tuple val("${task.process}"), val('pysam'), eval('python -c "import pysam; print(pysam.__version__)"'), topic: versions, emit: versions_pysam
    // tuple val("${task.process}"), val('uhvdb_genecoverage'), eval('uhvdb_genecoverage.py --version'), topic: versions, emit: versions_uhvdb_genecoverage

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ""
    """
    ### Index BAM for pysam random access
    python -c "import pysam; pysam.index('${bam}')"

    ### Compute per-gene coverage metrics
    uhvdb_genecoverage.py \\
        --bam ${bam} \\
        --annotations ${annotations_tsv_gz} \\
        --output ${prefix}.gene_coverage.tsv \\
        ${args}

    ### Compress (container has no gzip binary)
    python -c "import gzip, shutil; src='${prefix}.gene_coverage.tsv'; shutil.copyfileobj(open(src,'rb'), gzip.open(src+'.gz','wb')); __import__('os').unlink(src)"
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    python -c "import gzip; gzip.open('${prefix}.gene_coverage.tsv.gz', 'wt').write('')"
    """
}
