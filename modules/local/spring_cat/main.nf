process SPRING_CAT {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f6/f67f27c8cb2d1a149564f1a10f5f2b7a6acfa87ef3d3d27d2d8752dbe95e6acf/data' :
        'community.wave.seqera.io/library/spring:1.1.1--911a17b4ccfb85ee' }"

    input:
    tuple val(meta), path(spring)

    output:
    tuple val(meta), path("*.spring"), emit: spring

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def spring_list     = spring.collect { _spring -> _spring.toString() }.join(',')
    """
    IFS=',' read -r -a spring_array <<< "${spring_list}"

    ### Extract spring archive
    for spring in "\${spring_array[@]}"; do
        echo \$spring
        spring \\
            --decompress \\
            --input-file \$spring \\
            --output-file \${spring}.fastq.gz \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    done

    ### Concatenate fastqs
    for spring in "\${spring_array[@]}"; do
        echo \$spring
        if [ -f \${spring}.fastq.gz.2 ]; then
            cat \${spring}.fastq.gz.1 >> combined_R1.fastq.gz
            cat \${spring}.fastq.gz.2 >> combined_R2.fastq.gz
        else
            cat \${spring}.fastq.gz >> combined.fastq.gz
        fi
    done

    ### Convert to spring
    if [ -f combined_R2.fastq.gz ]; then
        spring \\
            --compress \\
            --input-file combined_R1.fastq.gz combined_R2.fastq.gz \\
            --output-file ${prefix}.spring \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    else
        spring \\
            --compress \\
            --input-file combined.fastq.gz \\
            --output-file ${prefix}.spring \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    fi

    ### Cleanup
    rm *.fastq.gz*
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" > ${prefix}.spring
    """
}
