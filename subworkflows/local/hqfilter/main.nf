include { rmEmptyFastAs; rmEmptyTsvs; add_split; extractDigitBeforeExtension } from '../functions/main'
include { FIND_CONCATENATE_TRTRIMMER            } from '../../../modules/local/find_concatenate_trtrimmer/main'
include { FIND_CONCATENATE                      } from '../../../modules/nf-core/find/concatenate/main'
include { VCLUST_CSVTK_SEQKIT                   } from '../../../modules/local/vclust_csvtk_seqkit/main'
include { CSVTK_SEQKIT                          } from '../../../modules/local/csvtk_seqkit/main'
include { KMERDB_LZANI_CSVTK_SEQKIT             } from '../../../modules/local/kmerdb_lzani_csvtk_seqkit/main'
include { CHECKV_UPDATEDATABASE                 } from '../../../modules/nf-core/checkv/updatedatabase/main'
include { CHECKV_COMPLETENESS                   } from '../../../modules/local/checkv/completeness/main'
include { UHVDB_HQFILTER                        } from '../../../modules/local/uhvdb/hqfilter/main'
include { FIND_CONCATENATEHEADERS               } from '../../../modules/local/find/concatenateheaders/main'

workflow HQFILTER {
    take:
    virus_fna_gz    // channel: [ val(meta), fna ]
    complete_fna_gz // channel: [ val(meta), fna ]
    classify_tsv_gz // channel: [ val(meta), tsv ]
    checkv_db       // channel: [ val(meta), checkv_db ]

    main:
    //
    // MODULE: Combine and trim DTRs from complete sequences
    //
    FIND_CONCATENATE_TRTRIMMER(
        rmEmptyFastAs(complete_fna_gz).map { _meta, fasta -> [ fasta] }.collect().map { fastas -> [ [ id: 'complete_viruses' ], fastas ] }
    )

    // Define vclust input if there are enough complete sequences for an update
    ch_vclust_input = FIND_CONCATENATE_TRTRIMMER.out.fna_gz
        .map { meta, fasta -> [ meta, fasta, fasta.countFasta() ] }
        .filter { _meta, _fasta, count -> count >= 2 || workflow.stubRun }
        .map { meta, fasta, _count -> [ meta, fasta ] }

    //
    // SUBWORKFLOW: Cluster complete viruses for update
    //
    VCLUST_CSVTK_SEQKIT(
        ch_vclust_input
    )

    //
    // MODULE: Align complete reps to CheckV database and extract novel sequences
    //
    KMERDB_LZANI_CSVTK_SEQKIT(
        VCLUST_CSVTK_SEQKIT.out.fna_gz,
        checkv_db.map { db -> [ [ id: 'checkv_reps' ], db.resolve('genome_db/checkv_reps.fna') ] }
    )

    //
    // MODULE: Update CheckV with new sequences
    //
    CHECKV_UPDATEDATABASE(
        KMERDB_LZANI_CSVTK_SEQKIT.out.fna_gz,
        checkv_db
    )
    // Prefer the updated DB when the update path ran; otherwise keep the original
    // (update is skipped when fewer than 2 complete sequences are available).
    ch_updated_checkv_db = CHECKV_UPDATEDATABASE.out.checkv_db
        .map { _meta, db -> db }
        .ifEmpty(checkv_db)
        .collect()

    //
    // MODULE: Calculate completeness using updated database
    //
    CHECKV_COMPLETENESS(
        rmEmptyFastAs(virus_fna_gz),
        ch_updated_checkv_db
    )

    //
    // MODULE: Extract HQ sequences using new estimates
    //
    UHVDB_HQFILTER(
        virus_fna_gz
            .join(classify_tsv_gz)
            .join(CHECKV_COMPLETENESS.out.tsv_gz)
    )

    //
    // MODULE: Combine HQ filter tsv file
    //
    FIND_CONCATENATEHEADERS(
        CHECKV_COMPLETENESS.out.tsv_gz.map { _meta, tsv_gz -> [ tsv_gz ] }.collect().map { tsv_gzs -> [ [ id:'combined_hqfilter' ], tsv_gzs ] },
        1
    )

    emit:
    fna_gz = UHVDB_HQFILTER.out.fna_gz
    tsv_gz = CHECKV_COMPLETENESS.out.tsv_gz
    combined_tsv_gz = FIND_CONCATENATEHEADERS.out.file_out
}
