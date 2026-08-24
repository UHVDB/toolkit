process UHVDB_PHISTHOST {
    tag "${meta.id}"
    label 'process_super_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data'
        : 'community.wave.seqera.io/library/polars:1.41.2--4850c76470baf071'}"

    input:
    tuple val(meta), path(csv_gzs, stageAs: "input_files/*")
    path(uhbdb_dir)

    output:
    tuple val(meta), path("${meta.id}_phist.tsv.gz")    , emit: phist_tsv_gz
    tuple val(meta), path("${meta.id}_phisthost.tsv.gz"), emit: phisthost_tsv_gz

    script:
    """
    ### Extract headers from the first file and write to output CSV
    for file in input_files/*; do
        zcat \$file | head -n 1 >> ${meta.id}.csv || [ \${PIPESTATUS[0]} -eq 0 -o \${PIPESTATUS[0]} -eq 141 ]
        break
    done

    ### Combine files
    for file in input_files/*; do
        if [ \$(zcat \$file | wc -l) -gt 2 ]; then
            zcat \$file | tail -n +3 >> ${meta.id}.csv
        else
            echo "File \$file has only header line or is empty; skipping content append."
        fi
    done

    ### Identify consensus host
    uhvdb_phisthost.py \\
        --uhbdb_dir ${uhbdb_dir} \\
        --phist_csv ${meta.id}.csv \\
        --output ${meta.id}

    ### Compress
    gzip ${meta.id}_phist.tsv ${meta.id}_phisthost.tsv

    ### Cleanup
    rm ${meta.id}.csv
    """

    stub:
    """
    echo "" | gzip > ${meta.id}_phist.tsv.gz
    echo "" | gzip > ${meta.id}_phisthost.tsv.gz
    """
}
