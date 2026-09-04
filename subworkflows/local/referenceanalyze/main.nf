include { SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE     } from '../../../modules/local/sracha_fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage/main'
include { FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE            } from '../../../modules/local/fastp_deacon_sylph_csvtk_seqkit_coverm_genecoverage/main'
include { SYLPHTAX_DOWNLOAD                                              } from '../../../modules/local/sylphtax/download/main'
include { SYLPHTAX_TAXPROF                                               } from '../../../modules/nf-core/sylphtax/taxprof/main'
include { SYLPHTAX_MERGE                                                 } from '../../../modules/nf-core/sylphtax/merge/main'
include { UHVDB_REFERENCEACTIVITY                                        } from '../../../modules/local/uhvdb/referenceactivity/main'
include { PILEA_DOWNLOAD                                                 } from '../../../modules/local/pilea/download/main'

workflow REFERENCEANALYZE {

    take:
    reads
    sras
    deacon_idx
    species_reps_fna_gz
    syldb
    uhvdb_metadata_tsv_gz
    uhvdb_metadata_sylphtax_tsv_gz
    uhvdb_protein_annotations

    main:

    //
    // MODULE: Download pilea GTDB database
    //
    PILEA_DOWNLOAD()
    ch_pilea_db = PILEA_DOWNLOAD.out.db.collect()

    //
    // MODULE: Download, preprocess, and analyse SRA reads against UHVDB
    //
    SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE(
        sras,
        deacon_idx,
        syldb,
        species_reps_fna_gz,
        uhvdb_protein_annotations,
        ch_pilea_db
    )
    ch_profile_tsv = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.tsv
    ch_depth_tsv_gz = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.depth_tsv_gz
    ch_gene_coverage_tsv_gz = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.gene_coverage_tsv_gz
    ch_pilea_tsv = SRACHA_FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.pilea_tsv

    //
    // MODULE: Preprocess and analyse local reads against UHVDB
    //
    FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE(
        reads,
        deacon_idx,
        syldb,
        species_reps_fna_gz,
        uhvdb_protein_annotations,
        ch_pilea_db
    )
    ch_profile_tsv = ch_profile_tsv.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.tsv)
    ch_depth_tsv_gz = ch_depth_tsv_gz.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.depth_tsv_gz)
    ch_gene_coverage_tsv_gz = ch_gene_coverage_tsv_gz.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.gene_coverage_tsv_gz)
    ch_pilea_tsv = ch_pilea_tsv.mix(FASTP_DEACON_SYLPH_CSVTK_SEQKIT_COVERM_GENECOVERAGE.out.pilea_tsv)

    //
    // MODULE: Download GTDB taxonomy metadata for sylph-tax
    //
    SYLPHTAX_DOWNLOAD()
    ch_taxonomy = SYLPHTAX_DOWNLOAD.out.tsv_gz
        .concat(uhvdb_metadata_sylphtax_tsv_gz.flatten())
        .collect()

    //
    // MODULE: Run sylph-tax
    //
    SYLPHTAX_TAXPROF(
        ch_profile_tsv,
        ch_taxonomy
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
        .join(ch_pilea_tsv)

    //
    // MODULE: Score Caudoviricetes detections with the figure_s15 inactive-virus classifier
    //
    UHVDB_REFERENCEACTIVITY(
        ch_sylphtax_for_referenceactivity,
        uhvdb_metadata_tsv_gz,
        channel.fromPath("${projectDir}/assets/models/phage_activity_model_full.joblib", checkIfExists: true).first(),
        channel.fromPath("${projectDir}/assets/models/phage_model_metadata_full.joblib", checkIfExists: true).first()
    )

    emit:
    sylphmpa = UHVDB_REFERENCEACTIVITY.out.sylphmpa
}
