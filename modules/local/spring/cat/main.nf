process SPRING_CAT {
    tag "${meta.id}"
    label 'process_high'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f6/f67f27c8cb2d1a149564f1a10f5f2b7a6acfa87ef3d3d27d2d8752dbe95e6acf/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ad27dd6990039308_1?_gl=1*17injuu*_gcl_au*NjY1ODA2Mjk0LjE3NjM0ODUwMTIuMTQxNjI4MTE1Ny4xNzY2NTMzMzE5LjE3NjY1MzMzMTk.

    input:
    tuple val(meta), path(springs)

    output:
    tuple val(meta), path("${meta.id}.spring")  , emit: spring
    path(".command.log")                        , emit: log
    path(".command.sh")                         , emit: script

    script:
    def spring_list     = springs.collect { spring -> spring.toString() }.join(',')
    """
    IFS=',' read -r -a spring_array <<< "${spring_list}"

    ### Extract spring archive ###
    for spring in "\${spring_array[@]}"; do
        echo \$spring
        spring \\
            --decompress \\
            --input-file \$spring \\
            --output-file \${spring}.fastq.gz \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    done

    ### Concatenate fastqs ###
    for spring in "\${spring_array[@]}"; do
        echo \$spring
        if [ -f \${spring}.fastq.gz.2 ]; then
            cat \${spring}.fastq.gz.1 >> combined_R1.fastq.gz
            cat \${spring}.fastq.gz.2 >> combined_R2.fastq.gz
        else
            cat \${spring}.fastq.gz >> combined.fastq.gz
        fi
    done

    ### Convert to spring ###
    if [ -f combined_R2.fastq.gz ]; then
        spring \\
            --compress \\
            --input-file combined_R1.fastq.gz combined_R2.fastq.gz \\
            --output-file ${meta.id}.spring \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    else
        spring \\
            --compress \\
            --input-file combined.fastq.gz \\
            --output-file ${meta.id}.spring \\
            --gzipped-fastq \\
            --num-threads ${task.cpus}
    fi

    ### Cleanup ###
    rm *.fastq.gz*
    """
}
