process ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT {
    tag "${meta.id}"
    label 'process_high'

    conda ( "${moduleDir}/environment.yml" )
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8e/8ebf1ebcc0beb6209556c55bf8fb291c8781b19ed3bc820cc69ad8bfba16b752/data'
        : 'community.wave.seqera.io/library/genomad_seqkit_aria2_csvtk:61faae14dee3888a'}"

    input:
    tuple val(meta), val(id_urls)
    path(genomad_db)

    output:
    tuple val(meta), path("*_virus.fna.gz")        , emit: fna_gz
    tuple val(meta), path("*_virus_summary.tsv.gz"), emit: summary_tsv_gz
    tuple val(meta), path("*_virus_genes.tsv.gz")  , emit: genes_tsv_gz
    tuple val("${task.process}"), val('genomad'), eval("genomad --version 2>&1 | sed 's/^.*geNomad, version //; s/ .*//'"), topic: versions, emit: versions_genomad
    tuple val("${task.process}"), val('seqkit'), eval("seqkit version | sed 's/^.*v//'"), emit: versions_seqkit, topic: versions
    tuple val("${task.process}"), val("aria2"), eval("aria2c --version 2>&1 | sed -n 's/^aria2 version \\([^ ]*\\).*/\\1/p'"), emit: versions_aria2, topic: versions
    tuple val("${task.process}"), val('csvtk'), eval("csvtk version | sed -e 's/csvtk v//g'"), emit: versions_csvtk, topic: versions

    script:
    def url_list   = id_urls.collect { id_url -> id_url[1].toString() + ',\sout=' + id_url[0].toString() + '.fna.gz' }.join(',')
    def prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    """
    ### Create arrays
    mkdir -p tmp
    IFS=',' read -r -a download_array <<< "${url_list}"
    printf '%s\\n' "\${download_array[@]}" > aria2_file.tsv

    ### Download assemblies
    for try in {1..6}; do
        aria2c \\
            --input=aria2_file.tsv \\
            --dir=tmp/ \\
            --max-connection-per-server=${task.cpus} \\
            --split=${task.cpus} \\
            --max-tries=10 \\
            --retry-wait=30 \\
            --max-concurrent-downloads=${task.cpus} && break || sleep \$((\$try^2*60))
    done

    ### Remove short contigs
    for file in tmp/*.fna.gz; do
        sample_id=\$(basename \${file} .fna.gz)

        seqkit \\
            seq \\
            --threads ${task.cpus} \\
            --min-len 2000 \\
            \$file \\
        | seqkit replace \\
            --threads ${task.cpus} \\
            -p ^ -r "\${sample_id}_" \\
            --out-file \${sample_id}.fna.gz

        rm \$file
    done

    ### Run geNomad
    cat ./*.fna.gz > combined_filtered.fasta.gz

    genomad \\
        end-to-end \\
        combined_filtered.fasta.gz \\
        genomad_results \\
        ${genomad_db} \\
        --threads ${task.cpus} \\
        ${args}

    ### Save virus outputs
    gzip -c genomad_results/*_summary/*_virus_summary.tsv > ${prefix}_virus_summary.tsv.gz
    gzip -c genomad_results/*_summary/*_virus_genes.tsv > ${prefix}_virus_genes.tsv.gz
    
    ### Remove LQ
    csvtk filter2 \\
        ${prefix}_virus_summary.tsv.gz \\
        --num-cpus ${task.cpus} \\
        ${args2} \\
        --out-file ${prefix}_filtered_genomad.txt

    seqkit grep \\
        genomad_results/*_summary/*_virus.fna \\
        --threads ${task.cpus} \\
        --pattern-file ${prefix}_filtered_genomad.txt \\
        --out-file ${prefix}_virus.fna.gz

    ### Cleanup
    rm -rf tmp/ genomad_results/ combined_filtered.fasta.gz ${prefix}_filtered_genomad.txt
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo "" | gzip > ${prefix}_virus.fna.gz
    echo "" | gzip > ${prefix}_virus_summary.tsv.gz
    echo "" | gzip > ${prefix}_virus_genes.tsv.gz
    """
}
