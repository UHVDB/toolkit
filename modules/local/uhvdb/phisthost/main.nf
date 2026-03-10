process UHVDB_PHISTHOST {
    tag "${meta.id}"
    label 'process_low'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/95/951a421e393d27a43650e0d55d6a1ae37ad4ce9f2124b14e29fce46853b6ac5c/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-a7bc37d3e43f08de_1?_gl=1*1rk09ym*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${params.output_dir}/${params.new_release_id}/uhvdb/phisthost/"

    input:
    tuple val(meta), path(csv_gzs, stageAs: "input_files/*")

    output:
    tuple val(meta), path("uhvdb.phist.tsv.gz")        , emit: phist_tsv_gz
    tuple val(meta), path("uhvdb.phisthost.tsv.gz")    , emit: phisthost_tsv_gz
    path ".command.log"                                 , emit: log
    path ".command.sh"                                  , emit: script

    script:
    """
    ### Extract headers from the first file and write to output CSV
    for file in input_files/*; do
        zcat \$file | head -n 1 >> ${meta.id}.csv
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
        --host_info ${projectDir}/assets/zenodo/gtdb/GTDB_Host_Info.tsv.gz \\
        --phist_csv ${meta.id}.csv \\
        --output uhvdb

    ### Compress
    gzip uhvdb.phist.tsv uhvdb.phisthost.tsv

    ### Cleanup
    rm ${meta.id}.csv
    """
}
