/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmEmptyTsvs(ch_tsvs) {
    def ch_nonempty_tsvs = ch_tsvs
        .filter { _meta, tsv ->
            try {
                file(tsv).countLines( limit: 2 ) > 1
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmEmptyTsvss]: ${tsv} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmEmptyTsvss]: ${tsv} has an EOFException, this is likely an empty gzipped file."
            }
        }
    return ch_nonempty_tsvs
}

// MODULES
include { CSVTK_FILTER2                 } from '../../../modules/local/csvtk/filter2'
include { DIAMOND_BLASTP                } from '../../../modules/local/diamond/blastp'
include { DIAMOND_BLASTPSELF            } from '../../../modules/local/diamond/blastpself'
include { DIAMOND_MAKEDB                } from '../../../modules/local/diamond/makedb'
include { MCL                           } from '../../../modules/local/mcl'
include { PROTEINSIMILARITY_SELFSCORE   } from '../../../modules/local/proteinsimilarity/selfscore'
include { PROTEINSIMILARITY_NORMSCORE   } from '../../../modules/local/proteinsimilarity/normscore'
include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2'
include { UHVDB_CATNOHEADER             } from '../../../modules/local/uhvdb/catnoheader'

// SUBWORKFLOWS
include { MCLCLUSTER as MCLCLUSTER_SUBFAMILY    } from '../../../subworkflows/local/mclcluster'
include { MCLCLUSTER as MCLCLUSTER_GENUS        } from '../../../subworkflows/local/mclcluster'
include { MCLCLUSTER as MCLCLUSTER_SUBGENUS     } from '../../../subworkflows/local/mclcluster'

workflow AAICLUSTER {

    take:
    taxa_virus_fna_gz   // channel: [ [ meta ], virus.taxa_reps.fna.gz ]

    main:

    if ( file("${params.uhvdb_dir}/*_species_reps.fna.gz").size() > 0 ) {
        ch_ref_fna_gz = channel.fromPath("${params.uhvdb_dir}/*_species_reps.fna.gz")
            .map { fna_gz -> taxa = fna_gz.getBaseName().split('_species_reps')[0]; [ [ id: "${taxa}_species_reps", taxa: taxa ], fna_gz ] }
    } else {
        ch_ref_fna_gz = taxa_virus_fna_gz
    }

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.taxa_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.taxa_reps.part_*.fna.gz ... ] ]
    // steps:
    // - Split fasta into chunks (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        taxa_virus_fna_gz,
        10000
    )
    ch_taxa_split_viruses_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            def taxa = fna_gz.getBaseName().toString() =~ /taxa([^\.]+)\.part/
            [ [ id: fna_gz.getBaseName(), taxa: taxa[0][1] ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: DIAMOND_MAKEDB
    // inputs:
    // - [ [ meta ], virus.taxa_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], virus.taxa_reps.dmnd ]
    // steps:
    // - Convert FNA to FAA (script)
    // - Create DIAMOND database (script)
    // - Cleanup (script)
    //--------------------------------------------
    DIAMOND_MAKEDB(
        ch_ref_fna_gz
    )

    //-------------------------------------------
    // MODULE: DIAMOND_BLASTP
    // inputs:
    // - [ [ meta ], virus.taxa_reps.part_*.fna.gz ]
    // - [ [ meta ], virus.taxa_reps.dmnd ]
    // outputs:
    // - [ [ meta ], virus.taxa_reps.part_*.blastp.tsv.gz ]
    // - [ [ meta ], virus.taxa_reps.part_*.faa.gz ]
    // steps:
    // - Convert FNA to FAA (script)
    // - Run DIAMOND (script)
    // - Compress (script)
    //--------------------------------------------
    ch_diamond_blastp_input = ch_taxa_split_viruses_fna_gz.map { meta, fna_gz -> [ meta.taxa, meta, fna_gz ] }
        .combine(DIAMOND_MAKEDB.out.dmnd.map { meta, dmnd -> [ meta.taxa, meta, dmnd ] }, by:0)
        .map { _taxa, meta, fna_gz, _meta2, dmnd -> [ meta, fna_gz, dmnd ] }
    DIAMOND_BLASTP(
        ch_diamond_blastp_input
    )

    //-------------------------------------------
    // MODULE: DIAMOND_BLASTPSELF
    // inputs:
    // - [ [ meta ], virus.taxa_reps.part_*.faa.gz ]
    // outputs:
    // - [ [ meta ],  virus.taxa_reps.part_*.blastpself.tsv.gz ]
    // steps:
    // - Make self DB (script)
    // - Align to self (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    DIAMOND_BLASTPSELF(
        DIAMOND_BLASTP.out.faa_gz
    )

    //-------------------------------------------
    // MODULE: PROTEINSIMILARITY_SELFSCORE
    // inputs:
    // - [ [ meta ], virus.taxa_reps.part_*.blastpself.tsv.gz ]
    // outputs:
    // - [ [ meta ], virus.taxa_reps.part_*.selfscore.tsv.gz ]
    // steps:
    // - Calculate self score (script)
    // - Compress (script)
    //--------------------------------------------
    PROTEINSIMILARITY_SELFSCORE(
        DIAMOND_BLASTPSELF.out.tsv_gz
    )

    //-------------------------------------------
    // MODULE: PROTEINSIMILARITY_NORMSCORE
    // inputs:
    // - [ [ meta ], virus.taxa_reps.part_*.selfscore.tsv.gz, virus.taxa_reps.part_*.blastp.tsv.gz ]
    // outputs:
    // - [ [ meta ], virus.taxa_reps.part_*.normscore.tsv.gz ]
    // steps:
    // - Calculate normalized score (script)
    // - Compress (script)
    //--------------------------------------------
    ch_normscore_input = PROTEINSIMILARITY_SELFSCORE.out.tsv_gz
        .combine(DIAMOND_BLASTP.out.tsv_gz, by:0)
    PROTEINSIMILARITY_NORMSCORE(
        ch_normscore_input
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATNOHEADER
    // inputs:
    // - [ [ meta ], [ norm_score.part_*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], aaicluster.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = PROTEINSIMILARITY_NORMSCORE.out.tsv_gz
        .map { meta, tsv_gz -> [ meta.taxa, meta, tsv_gz ] }
        .groupTuple()
        .map { meta_taxa, _meta, tsv_gz -> [ [ id:meta_taxa ], tsv_gz, 'tsv.gz' ] }
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/aaicluster/"
    )

    //-------------------------------------------
    // MODULE: CSVTK_FILTER2
    // inputs:
    // - [ [ meta ], aaicluster.tsv.gz ]
    // outputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // steps:
    // - Filter matrix (script)
    //--------------------------------------------
    CSVTK_FILTER2(
        UHVDB_CATNOHEADER.out.combined,
        5.5
    )

    //-------------------------------------------
    // MODULE: MCL
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - Decompress (script)
    // - Run MCL (script)
    //--------------------------------------------
    MCL(
        CSVTK_FILTER2.out.tsv_gz,
    )

    //-------------------------------------------
    // SUBWORKFLOW: MCLCLUSTER_SUBFAMILY
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // - [ [ meta ], aaicluster.mcl.gz ]
    // - similarity_threshold
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - UHVDB_PRUNE (module)
    // - MCL (script)
    //--------------------------------------------
    ch_mcl_subfamily_input = rmEmptyTsvs(CSVTK_FILTER2.out.tsv_gz).combine(rmEmptyTsvs(MCL.out.mcl_gz), by:0)
    MCLCLUSTER_SUBFAMILY(
        ch_mcl_subfamily_input,
        32.0
        )

    //-------------------------------------------
    // SUBWORKFLOW: MCLCLUSTER_GENUS
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // - [ [ meta ], aaicluster.mcl.gz ]
    // - similarity_threshold
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - UHVDB_PRUNE (module)
    // - MCL (script)
    //--------------------------------------------
    ch_mcl_genus_input = rmEmptyTsvs(CSVTK_FILTER2.out.tsv_gz).combine(rmEmptyTsvs(MCLCLUSTER_SUBFAMILY.out.mcl_gz), by:0)
    MCLCLUSTER_GENUS(
        ch_mcl_genus_input,
        65.0
    )

    //-------------------------------------------
    // SUBWORKFLOW: MCLCLUSTER_SUBGENUS
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // - [ [ meta ], aaicluster.mcl.gz ]
    // - similarity_threshold
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - UHVDB_PRUNE (module)
    // - MCL (script)
    //--------------------------------------------
    ch_mcl_subgenus_input = rmEmptyTsvs(CSVTK_FILTER2.out.tsv_gz).combine(rmEmptyTsvs(MCLCLUSTER_GENUS.out.mcl_gz), by:0)
    MCLCLUSTER_SUBGENUS(
        ch_mcl_subgenus_input,
        80.0
    )

    // emit:
    // proteinsimilarity_tsv_gz = PROTEINSIMILARITY_COMBINE.out.tsv_gz
}
