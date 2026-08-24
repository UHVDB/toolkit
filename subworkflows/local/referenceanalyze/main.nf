include { CSVTK_SEQKIT                                                   } from '../../../modules/local/csvtk_seqkit/main'
include { SYLPH_SKETCHGENOMES                                            } from '../../../modules/nf-core/sylph/sketchgenomes/main'
include { SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE     } from '../../../modules/local/sracha_fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage/main'
include { FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE            } from '../../../modules/local/fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage/main'
include { SYLPHTAX_TAXPROF                                               } from '../../../modules/nf-core/sylphtax/taxprof/main'
include { SYLPHTAX_MERGE                                                 } from '../../../modules/nf-core/sylphtax/merge/main'
include { UHVDB_REFERENCEACTIVITY                                        } from '../../../modules/local/uhvdb/referenceactivity/main'

workflow REFERENCEANALYZE {

    take:
    reads
    sras
    deacon_idx
    uhvdb_unique_reps_fna_gz
    uhvdb_metadata_tsv_gz
    uhvdb_metadata_sylphtax_tsv_gz
    uhvdb_protein_annotations

    main:

    //
    // MODULE: Extract species reps from UHVDB
    //
    CSVTK_SEQKIT(
        uhvdb_metadata_tsv_gz.combine(uhvdb_unique_reps_fna_gz).map { tsv_gz, fna_gz -> [ [ id: 'uhvdb' ], tsv_gz, fna_gz ] },
        "--tabs --filter '( \$uhvdb_id == \$species_rep )' | csvtk cut --tabs -f species_rep --out-delimiter '\t'",
        "",
        "species_reps"
    )

    //
    // MODULE: Create sylph sketch of species reps
    //
    SYLPH_SKETCHGENOMES(
        CSVTK_SEQKIT.out.fna_gz
    )

    ch_syldb = SYLPH_SKETCHGENOMES.out.syldb.collect().map { _meta, syldb -> [ syldb, file(params.bacteria_syldb) ] }
    ch_species_reps_fna_gz = CSVTK_SEQKIT.out.fna_gz.map { _meta, fna_gz -> fna_gz }.first()

    //
    // MODULE: Download, preprocess, and analyse SRA reads against UHVDB
    //
    SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE(
        sras,
        deacon_idx,
        ch_syldb,
        ch_species_reps_fna_gz,
        uhvdb_protein_annotations
    )
    ch_profile_tsv = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.tsv
    ch_depth_tsv_gz = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.depth_tsv_gz
    ch_gene_coverage_tsv_gz = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.gene_coverage_tsv_gz

    //
    // MODULE: Preprocess and analyse local reads against UHVDB
    //
    FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE(
        reads,
        deacon_idx,
        ch_syldb,
        ch_species_reps_fna_gz,
        uhvdb_protein_annotations
    )
    ch_profile_tsv = ch_profile_tsv.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.tsv)
    ch_depth_tsv_gz = ch_depth_tsv_gz.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.depth_tsv_gz)
    ch_gene_coverage_tsv_gz = ch_gene_coverage_tsv_gz.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.gene_coverage_tsv_gz)

    //
    // MODULE: Run sylph-tax
    //
    SYLPHTAX_TAXPROF(
        ch_profile_tsv,
        uhvdb_metadata_sylphtax_tsv_gz
    )

    //
    // MODULE: Merge sylph results
    //
    SYLPHTAX_MERGE(
        SYLPHTAX_TAXPROF.out.taxprof_output.map { _meta, sylphmpa -> [ [ id: 'sylptax_combined' ], sylphmpa ] }.groupTuple(),
        'relative_abundance'
    )

    ch_sylphtax_for_referenceactivity = SYLPHTAX_TAXPROF.out.taxprof_output
        .join(ch_depth_tsv_gz)
        .join(ch_profile_tsv)
        .join(ch_gene_coverage_tsv_gz)

    //
    // MODULE: Score Caudoviricetes detections with the figure_s15 inactive-virus classifier
    //
    UHVDB_REFERENCEACTIVITY(
        ch_sylphtax_for_referenceactivity,
        uhvdb_metadata_tsv_gz,
        channel.fromPath("${projectDir}/assets/models/phage_activity_model_full.joblib", checkIfExists: true).first(),
        channel.fromPath("${projectDir}/assets/models/phage_model_metadata_full.joblib", checkIfExists: true).first()
    )
}
