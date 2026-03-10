/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { BACPHLIP          } from '../../../modules/local/bacphlip'
include { SEQKIT_SPLIT2     } from '../../../modules/local/seqkit/split2'
include { UHVDB_CATHEADER   } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_LIFESTYLE   } from '../../../modules/local/uhvdb/lifestyle'

workflow LIFESTYLE {

    take:
    virus_fna_gz    // channel: [ [ meta ], virus.fna.gz ]
    classify_tsv_gz // channel: [ [ meta ], classify.tsv.gz ]
    pharokka_tsv_gz    // channel: [ [ meta ], pharokka.tsv.gz ]
    phold_tsv_gz    // channel: [ [ meta ], phold.tsv.gz ]
    empathi_csv_gz  // channel: [ [ meta ], empathi.csv.gz ]
    protein2hash_tsv_gz  // channel: [ [ meta ], protein2hash.tsv.gz ]

    main:

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.fna.gz ... ] ]
    // steps:
    // - Split sequences (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        virus_fna_gz,
        params.bacphlip_split_size
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fna", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: BACPHLIP
    // inputs:
    // - [ [ meta ], virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], bacphlip.part_*.tsv.gz ]
    // steps:
    // - Gunzip virus fna (script)
    // - Run BACPHLIP (script)
    // - Compress outputs (script)
    // - Cleanup (script)
    //--------------------------------------------
    BACPHLIP(
        ch_split_fna_gz
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ bacphlip.part_0*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], bacphlip.tsv.gz ]
    // steps:
    // - Print header line (script)
    // - Print non-header lines (script)
    // - Compress (script)
    //--------------------------------------------
    ch_catheader_input = BACPHLIP.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'bacphlip' ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/lifestyle"
    )

    //-------------------------------------------
    // MODULE: UHVDB_LIFESTYLE
    // inputs:
    // - [ [ meta ], bacphlip.tsv.gz ]
    // - [ [ meta ], classify.tsv.gz ]
    // - [ [ meta ], pharokka.tsv.gz ]
    // - [ [ meta ], phold.tsv.gz ]
    // - [ [ meta ], empathi.csv.gz ]
    // outputs:
    // - [ [ meta ], uhvdb_lifestyle.tsv.gz ]
    // steps:
    // - Combine lifestyle data (script)
    // - Compress (script)
    //--------------------------------------------
    UHVDB_LIFESTYLE(
        UHVDB_CATHEADER.out.combined,
        classify_tsv_gz,
        pharokka_tsv_gz,
        phold_tsv_gz,
        empathi_csv_gz,
        protein2hash_tsv_gz
    )

    emit:
    tsv_gz = UHVDB_LIFESTYLE.out.tsv_gz
}

