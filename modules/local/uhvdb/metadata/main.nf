process UHVDB_METADATA {
    tag "UHVDB metadata"
    label 'process_super_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/f6/f6f9d332e4b15ffa29e886f0224de4ed068d4ebff7e8dd3287c9c2b8521617a1/data' :
        'community.wave.seqera.io/library/taxopy_polars:ece13f10ab3ee41a' }"

    input:
    tuple val(meta1),  path(seqhasher_tsv_gz)
    tuple val(meta2),  path(mapping_tsv_gz)
    tuple val(meta3),  path(classify_tsv_gz)
    tuple val(meta4),  path(hqfilter_tsv_gz)
    tuple val(meta5),  path(hcfilter_tsv_gz)
    tuple val(meta6),  path(genomovar_info_tsv_gz)
    tuple val(meta7),  path(species_info_tsv_gz)
    tuple val(meta8),  path(aaicluster_tsv_gz)
    tuple val(meta9),  path(taxonomy_tsv_gz)
    tuple val(meta10), path(crisprhost_tsv_gz)
    tuple val(meta11), path(phisthost_tsv_gz)
    tuple val(meta12), path(proteinhash_tsv_gz)
    tuple val(meta13), path(bakta_tsv_gz)
    tuple val(meta14), path(foldseek_tsv_gz)
    tuple val(meta15), path(interproscan_tsv_gz)
    tuple val(meta16), path(card_tsv_gz)
    tuple val(meta17), path(vfdb_tsv_gz)
    tuple val(meta18), path(pharokka_tsv_gz)
    tuple val(meta19), path(phold_tsv_gz)
    tuple val(meta20), path(empathi_csv_gz)
    path(uhvdb_metadata_tsv_gz, stageAs: "uhvdb_old_metadata.tsv.gz")
    path(uhvdb_protein_annotations, stageAs: "uhvdb_old_protein_annotations")

    output:
    path("uhvdb_metadata.tsv.gz")            , emit: tsv_gz
    path("uhvdb_protein_annotations.tsv.gz") , emit: protein_annotations_tsv_gz

    script:
    def uhvdb_metadata = uhvdb_metadata_tsv_gz && uhvdb_metadata_tsv_gz.size() > 0 ? "--uhvdb-metadata ${uhvdb_metadata_tsv_gz}" : ""
    def protein_annot_arg = uhvdb_protein_annotations && uhvdb_protein_annotations.size() > 0 ? "--uhvdb-protein-annotations ${uhvdb_protein_annotations}" : ""
    """
    ### Build metadata and protein annotation tables
    uhvdb_build_metadata.py \\
        --seqhasher-tsv ${seqhasher_tsv_gz} \\
        --mapping-tsv ${mapping_tsv_gz} \\
        --classify-tsv ${classify_tsv_gz} \\
        --hqfilter-tsv ${hqfilter_tsv_gz} \\
        --hcfilter-tsv ${hcfilter_tsv_gz} \\
        --genomovar-info-tsv ${genomovar_info_tsv_gz} \\
        --species-info-tsv ${species_info_tsv_gz} \\
        --aaicluster-tsv ${aaicluster_tsv_gz} \\
        --taxonomy-tsv ${taxonomy_tsv_gz} \\
        --crisprhost-tsv ${crisprhost_tsv_gz} \\
        --phisthost-tsv ${phisthost_tsv_gz} \\
        --proteinhash-tsv ${proteinhash_tsv_gz} \\
        --bakta-tsv ${bakta_tsv_gz} \\
        --foldseek-tsv ${foldseek_tsv_gz} \\
        --interproscan-tsv ${interproscan_tsv_gz} \\
        --card-tsv ${card_tsv_gz} \\
        --vfdb-tsv ${vfdb_tsv_gz} \\
        --pharokka-tsv ${pharokka_tsv_gz} \\
        --phold-tsv ${phold_tsv_gz} \\
        --empathi-csv ${empathi_csv_gz} \\
        ${uhvdb_metadata} \\
        ${protein_annot_arg} \\
        --output-metadata uhvdb_metadata.tsv \\
        --output-protein-annotations uhvdb_protein_annotations.tsv

    ### Compress
    gzip uhvdb_metadata.tsv uhvdb_protein_annotations.tsv
    """

    stub:
    """
    echo "" | gzip > uhvdb_metadata.tsv.gz
    echo "" | gzip > uhvdb_protein_annotations.tsv.gz
    """
}
