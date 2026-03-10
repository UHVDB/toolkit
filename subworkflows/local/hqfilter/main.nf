/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmEmptyFastAs(ch_fastas) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: 1 ) > 0
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmEmptyFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmEmptyFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { CHECKV_COMPLETENESS   } from '../../../modules/local/checkv/completeness'
include { CHECKV_UPDATE         } from '../../../modules/local/checkv/update'
include { CHECKV_VCLUST         } from '../../../modules/local/checkv/vclust'
include { SEQKIT_SPLIT2         } from '../../../modules/local/seqkit/split2'
include { TRTRIMMER             } from '../../../modules/local/trtrimmer'
include { UHVDB_COMPLETEGENOMES } from '../../../modules/local/uhvdb/completegenomes'
include { UHVDB_CATHEADER       } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER     } from '../../../modules/local/uhvdb/catnoheader'
include { UHVDB_HQFILTER        } from '../../../modules/local/uhvdb/hqfilter'
include { VCLUST_ALL2ALL        } from '../../../modules/local/vclust/all2all'


workflow HQFILTER {

    take:
    fna_gz              // channel: [ [ meta ], fna.gz ]
    tsv_gz              // channel: [ [ meta ], tsv.gz ]
    checkv_db           // channel: [ checkv_db ]

    main:

    //-------------------------------------------
    // MODULE: UHVDB_COMPLETEGENOMES
    // inputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz, uhvdb_classify.fna.gz ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], complete_genomes.fna.gz ]
    // steps:
    // - Extract complete genomes (script)
    // - Cleanup (script)
    //--------------------------------------------
    ch_complete_genomes_input = tsv_gz.map { meta, tsv_gz -> meta.id = 'complete_viruses'; [ meta, tsv_gz ] }
        .combine(fna_gz.map { _meta, fna_gz -> fna_gz })
    
    UHVDB_COMPLETEGENOMES(
        ch_complete_genomes_input
    )

    //-------------------------------------------
    // MODULE: TRTRIMMER
    // inputs:
    // - [ [ meta ], complete_genomes.fna.gz ]
    // outputs:
    // - [ [ meta ], complete_genomes.tr-trimmer.fna.gz ]
    // steps:
    // - Trim DTRs (script)
    // - Compress (script)
    //--------------------------------------------
    TRTRIMMER(
        UHVDB_COMPLETEGENOMES.out.fna_gz
    )

    //-------------------------------------------
    // MODULE: VCLUST_ALL2ALL
    // inputs:
    // - [ [ meta ], virus_derep.reps.fna.gz ]
    // outputs:
    // - [ [ meta ], virus_genomovar.clusters.tsv.gz ]
    // - [ [ meta ], virus_genomovar.reps.fna.gz ]
    // steps:
    // - Run vClust (script)
    // - Extract reps (script)
    // - Compress (script)
    // - Cleanup (script)
    //-------------------------------------------
    VCLUST_ALL2ALL(
        TRTRIMMER.out.fna_gz,
        channel.of([]),
        0.95,     // min_ani
        0.85,     // min_af
        "${params.output_dir}/${params.new_release_id}_outputs/hqfilter/complete_viruses"
    )

    //-------------------------------------------
    // MODULE: CHECKV_VCLUST
    // inputs:
    // - [ [ meta ], complete_genomes.tr-trimmer.fna.gz ]
    // outputs:
    // - [ [ meta ], complete_genomes.species_reps.fna.gz ]
    // steps:
    // - Build ref DB (script)
    // - Compare query to ref (script)
    // - Convert output format (script)
    // - Align with LZ-ANI (script)
    // - Extract new species (script)
    // - Cleanup (script)
    //--------------------------------------------
    CHECKV_VCLUST(
        VCLUST_ALL2ALL.out.new_fna_gz,
        checkv_db
    )

    //-------------------------------------------
    // MODULE: CHECKV_UPDATE
    // inputs:
    // - [ [ meta ], complete_genomes.novel_checkv.fna.gz ]
    // outputs:
    // - [ checkv_updated/ ]
    // steps:
    // - Decompress (script)
    // - Update CheckV (script)
    // - Cleanup (script)
    //--------------------------------------------
    CHECKV_UPDATE(
        CHECKV_VCLUST.out.fna_gz,
        checkv_db
    )

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.fna.gz ... ] ]
    // steps:
    // - Split fasta into chunks (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        fna_gz,
        params.checkv_split_size
    )
    ch_split_viruses_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fna", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: CHECKV_ENDTOEND
    // inputs:
    // - [ [ meta ], [ virus.fna.gz ] ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Run CheckV (script)
    // - Save outputs (script)
    // - Fix provirus headers (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    CHECKV_COMPLETENESS(
        ch_split_viruses_fna_gz,
        CHECKV_UPDATE.out.checkv_db.first()
    )

    //-------------------------------------------
    // MODULE: UHVDB_HQFILTER
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Extract HQ viruses (script)
    // - Cleanup (script)
    //--------------------------------------------
    UHVDB_HQFILTER(
        ch_split_viruses_fna_gz.combine(CHECKV_COMPLETENESS.out.tsv_gz, by:0),
        tsv_gz.first()
    )


    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *_quality_summary.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = 
        CHECKV_COMPLETENESS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'completeness_2' ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}_outputs/hqfilter"
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATNOHEADER
    // inputs:
    // - [ [ meta ], [ *_uhvdb_hqfilter.fna.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.fna.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = UHVDB_HQFILTER.out.fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:'hq_viruses' ], fna_gz, 'fna.gz' ] }
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}_outputs/hqfilter"
    )

    emit:
    hq_viruses_fna_gz   = UHVDB_CATNOHEADER.out.combined
    hqfilter_tsv_gz     = UHVDB_CATHEADER.out.combined.filter { meta, _file -> meta.id == 'completeness_2' }
}

