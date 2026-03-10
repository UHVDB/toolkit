process UHVDB_RENAME {
    tag "${meta.id}"
    label 'process_medium'
    container "https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/54/54481f673ef3b37aa015a39d2ebef5e67d5559a104fee6b741b948e227e7f9b9/data"
    // Singularity: https://wave.seqera.io/view/builds/bd-ad38cc6b0f6e1c86_1?_gl=1*1bebhx1*_gcl_au*MTI1MzgxOTA5MC4xNzY4MjM1MzM1
    storeDir "${publish_dir}/${meta.id}"
    
    input:
    tuple val(meta) , path(files, stageAs: 'input_files/*')
    path(uhvdb_fna_gz)
    val(publish_dir)

    output:
    tuple val(meta) , path("${meta.id}.new_reps.fna.gz")    , emit: new_fna_gz
    tuple val(meta) , path("${meta.id}.reps.fna.gz")        , emit: all_fna_gz
    tuple val(meta) , path("${meta.id}.id_mapping.tsv.gz")  , emit: tsv_gz
    path(".command.log")                                    , emit: log
    path(".command.sh")                                     , emit: script

    script:
    def uhvdb_input = uhvdb_fna_gz ? true : false
    """
    ### Determine start value
    if [[ "${uhvdb_input}" == "true" ]]; then
        echo "Found existing UHVDB file: ${uhvdb_fna_gz}"
        start_num=\$((\$(zgrep -c "^>" ${uhvdb_fna_gz} )+1))
    else
        echo "No existing UHVDB file found. Starting from 0."
        start_num=1
    fi    

    ### Combine files
    for file in input_files/*; do
        if [[ \$file == *.gz ]]; then
            zcat \$file >> ${meta.id}.fna
        else
            cat \$file >> ${meta.id}.fna
        fi
    done

    ### Rename with UHVDB IDs
    awk -v start=\$start_num '/^>/ {
        old_id = substr(\$0, 2);
        new_id = "UHVDB-" start++;
        print ">" new_id;
        print old_id "\\t" new_id >> "${meta.id}.id_mapping.tsv";
        next
    } {print}' ${meta.id}.fna > ${meta.id}.new_reps.fna

    ### Compress
    pigz ${meta.id}.new_reps.fna ${meta.id}.id_mapping.tsv

    ### Combine new and old
    if [[ "${uhvdb_input}" == "true" ]]; then
        cat ${meta.id}.new_reps.fna.gz ${uhvdb_fna_gz} > ${meta.id}.reps.fna.gz
    else
        cp ${meta.id}.new_reps.fna.gz ${meta.id}.reps.fna.gz
    fi
    """
}
