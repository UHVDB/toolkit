/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmNonMultiFastAs(ch_fastas, min) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: min ) > (min - 1)
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmNonMultiFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmNonMultiFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
                false
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { MCL                           } from '../../../modules/local/mcl'
include { UHVDB_ANIREPS                 } from '../../../modules/local/uhvdb/anireps'
include { VCLUST_NEW2ALL                } from '../../../modules/local/vclust/new2all'
include { VCLUST_NEW2NEW                } from '../../../modules/local/vclust/new2new'


workflow ANICLUSTER {

    take:
    virus_fna_gz        // channel: [ [ meta ], virus.fna.gz ]
    virus_tsv_gz        // channel: [ [ meta ], virus.tsv.gz ]
    completeness_tsv_gz // channel: [ [ meta ], virus_completeness.tsv.gz ]

    main:

    if ( file("${params.uhvdb_dir}/*_genomovar_reps.fna.gz").size() > 0 ) {
        ch_ref_fna_gz = channel.fromPath("${params.uhvdb_dir}/*_genomovar_reps.fna.gz")
            .map { fna_gz -> taxa = fna_gz.getBaseName().split('_genomovar_reps')[0]; [ [ id: "${taxa}_genomovar_reps", taxa: taxa ], fna_gz ] }
        ch_uhvdb_species_graph = channel.fromPath("${params.uhvdb_dir}/*_species_graph.tsv.gz")
            .map { graph_gz -> taxa = graph_gz.getBaseName().split('_species_graph')[0]; [ [ id: "${taxa}_species_graph", taxa: taxa ], graph_gz ] }
        ch_uhvdb_metadata_tsv_gz = channel.fromPath("${params.uhvdb_dir}/*_metadata.tsv.gz")
            .map { tsv_gz -> [ tsv_gz ] }
    } else {
        ch_ref_fna_gz = channel.of([])
        ch_uhvdb_species_graph = channel.empty()
        ch_uhvdb_metadata_tsv_gz = channel.of([])
    }

    //-------------------------------------------
    // MODULE: VCLUST_NEW2ALL
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], *.vclust_gani_new2all.tsv.gz ]
    // steps:
    // - Build reference DB (script)
    // - Compare query to reference (script)
    // - Convert output format (script)
    // - Align with LZ-ANI (script)
    // - Extract gANIs (script)
    // - Cleanup (script)
    //--------------------------------------------
    if ( file("${params.uhvdb_dir}/*_genomovar_reps.fna.gz").size() > 0 ) {
        VCLUST_NEW2ALL(
            virus_fna_gz.map { meta, fna_gz -> [ meta.taxa, meta, fna_gz ] }
                .combine(ch_ref_fna_gz.map { meta, fna_gz -> [ meta.taxa, fna_gz ] }, by:0)
                .map { _meta_taxa, meta, fna_gz, ref_fna_gz -> [ meta, fna_gz, ref_fna_gz ] }
        )
    }

    //-------------------------------------------
    // MODULE: VCLUST_NEW2NEW
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], virus.vclust_gani_new2new.tsv.gz ]
    // steps:
    // - Run vClust (script)
    // - Extract gANIs (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    VCLUST_NEW2NEW(
        rmNonMultiFastAs(virus_fna_gz, 2)
    )

    //-------------------------------------------
    // MODULE: MCL
    // inputs:
    // - [ [ meta ], [ *.vclust_gani_new2all.tsv.gz ... ] ]
    // - [ [ meta ], *.mcl.gz ]
    // steps:
    // - Decompress (script)
    // - Run MCL (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    if ( file("${params.uhvdb_dir}/*_genomovar_reps.fna.gz").size() > 0 ) {
        ch_mcl_input = VCLUST_NEW2NEW.out.gani_gz.map { meta, gani_gz -> [ meta.taxa, meta, gani_gz ] }
            .combine( VCLUST_NEW2ALL.out.gani_gz.map { meta, gani_gz -> [ meta.taxa, gani_gz ] }, by:0)
            .combine(ch_uhvdb_species_graph.map { meta, gani_gz -> [ meta.taxa, gani_gz ] }, by:0)
            .map{ _meta_taxa, meta, new2all, new2new, uhvdb -> [ meta, new2all, new2new, uhvdb ] }
    } else {
        ch_mcl_input = VCLUST_NEW2NEW.out.gani_gz
            .map { meta, gani_gz -> [ meta, gani_gz ] }
    }

    MCL(
        ch_mcl_input
    )

    //-------------------------------------------
    // MODULE: UHVDB_ANIREPS
    // inputs:
    // - [ [ meta ], virus.fna.gz, ?ref.fna.gz, *.tsv.gz, *_completeness.tsv.gz, *.mcl.gz, ?uhvdb_metadata.tsv.gz ]
    // outputs:
    // - [ [ meta ], *.anireps.fna.gz ]
    // steps:
    // - Extract all IDs (script)
    // - Identify ANI reps (script)
    // - Extract rep sequences (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------   
    if ( file("${params.uhvdb_dir}/*_genomovar_reps.fna.gz").size() > 0 ) {
        UHVDB_ANIREPS(
            virus_fna_gz.map { meta, fna_gz -> [ meta, fna_gz ] }
                .combine(ch_ref_fna_gz.map { meta, fna_gz -> [ meta.id, fna_gz ] }, by:0)
                .combine(virus_tsv_gz.map { _meta, tsv_gz -> tsv_gz })
                .combine(completeness_tsv_gz.map { _meta, completeness_tsv_gz -> completeness_tsv_gz })
                .combine(MCL.out.mcl_gz.map { meta, fna_gz -> [ meta.id, fna_gz ] }, by:0)
                .combine(ch_uhvdb_metadata_tsv_gz)
                .map { _meta_id, meta, fna_gz, ref_fna_gz, tsv_gz, completeness_tsv_gz, mcl_gz, uhvdb_metadata_tsv_gz ->
                    [ meta, fna_gz, ref_fna_gz, tsv_gz, completeness_tsv_gz, mcl_gz, uhvdb_metadata_tsv_gz ] 
                }
        )
    } else {
        UHVDB_ANIREPS(
            virus_fna_gz
                .combine(virus_tsv_gz.map { _meta, tsv_gz -> tsv_gz })
                .combine(completeness_tsv_gz.map { _meta, completeness_tsv_gz -> completeness_tsv_gz })
                .combine(MCL.out.mcl_gz, by:0)
                .map { meta, fna_gz, classify_tsv_gz, completeness_tsv_gz, mcl_gz ->
                    [ meta, fna_gz, [], classify_tsv_gz, completeness_tsv_gz, mcl_gz, []] 
                }
        )
    }

    emit:
    tsv_gz = UHVDB_ANIREPS.out.tsv_gz
    fna_gz = UHVDB_ANIREPS.out.fna_gz
}
