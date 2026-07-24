include { CSVTK_SEQKIT          } from '../../../modules/local/csvtk_seqkit/main'
include { SYLPH_SKETCHGENOMES   } from '../../../modules/nf-core/sylph/sketchgenomes/main'
include { SPRING_SYLPH           } from '../../../modules/local/spring_sylph/main'
include { SYLPHTAX_TAXPROF       } from '../../../modules/nf-core/sylphtax/taxprof/main'
include { SYLPHTAX_MERGE         } from '../../../modules/nf-core/sylphtax/merge/main'
include { CSVTK_SEQKIT as CSVTK_SEQKIT_SYLPH } from '../../../modules/local/csvtk_seqkit/main'
include { SPRING_COVERM } from '../../../modules/local/spring_coverm/main'
include { UHVDB_GENECOVERAGE } from '../../../modules/local/uhvdb/genecoverage/main'
include { UHVDB_REFERENCEACTIVITY } from '../../../modules/local/uhvdb/referenceactivity/main'
include { rmEmptyTsvs; rmEmptyFastAs } from '../functions/main'

workflow REFERENCEANALYZE {

    take:
    spring
    uhvdb_unique_reps_fna_gz
    uhvdb_metadata_tsv_gz
    uhvdb_metadata_sylphtax_tsv_gz
    uhvdb_protein_annotations_tsv_gz

    main:

    //
    // MODULE: Extract species reps from UHVDB
    //
    CSVTK_SEQKIT(
        uhvdb_metadata_tsv_gz.combine(uhvdb_unique_reps_fna_gz).map { tsv_gz, fna_gz -> [ [ id: 'uhvdb' ], tsv_gz, fna_gz ] }
    )

    //
    // MODULE: Create sylph sketch of species reps
    //
    SYLPH_SKETCHGENOMES(
        CSVTK_SEQKIT.out.fna_gz
    )

    //
    // MODULE: Identify contained genomes with spring and sylph
    //
    SPRING_SYLPH(
        spring,
        SYLPH_SKETCHGENOMES.out.syldb.collect().map { _meta, syldb -> [ syldb, file(params.bacteria_syldb) ] }
    )

    //
    // MODULE: Run sylph-tax
    //
    SYLPHTAX_TAXPROF(
        SPRING_SYLPH.out.tsv,
        uhvdb_metadata_sylphtax_tsv_gz
    )

    //
    // MODULE: Merge sylph results
    //
    SYLPHTAX_MERGE(
        SYLPHTAX_TAXPROF.out.taxprof_output.map { _meta, sylphmpa -> [ [ id: 'sylptax_combined' ], sylphmpa ] }.groupTuple(),
        'relative_abundance'
    )

    //
    // MODULE: Extract contained viruses from sylph output
    //
    CSVTK_SEQKIT_SYLPH(
        SPRING_SYLPH.out.tsv.combine(rmEmptyFastAs(CSVTK_SEQKIT.out.fna_gz)).map { meta, tsv, _meta2, fna_gz -> [ meta, tsv, fna_gz ] }
    )

    //
    // MODULE: Align reads to contained viruses
    //
    SPRING_COVERM(
        spring.join(rmEmptyFastAs(CSVTK_SEQKIT_SYLPH.out.fna_gz))
    )

    //
    // MODULE: Compute per-gene coverage for contained viruses
    //
    UHVDB_GENECOVERAGE(
        SPRING_COVERM.out.bam,
        uhvdb_protein_annotations_tsv_gz
    )

    // //
    // // MODULE: Assign activity tier to each reference genome
    // //
    // UHVDB_REFERENCEACTIVITY(
    //     rmEmptyTsvs(SYLPHTAX_TAXPROF.out.taxprof_output).combine(rmEmptyTsvs(SPRING_COVERM.out.tsv_gz), by:0),
    //     uhvdb_metadata_tsv_gz,
    //     "${projectDir}/assets/models/phage_activity_model_full.joblib",
    //     "${projectDir}/assets/models/phage_model_metadata_full.joblib"
    // )
}
