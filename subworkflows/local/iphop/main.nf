/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SEQKIT_SPLIT2         } from '../../../modules/local/seqkit/split2'
include { IPHOP_DOWNLOAD        } from '../../../modules/local/iphop/download'
include { IPHOP_PREDICT         } from '../../../modules/local/iphop/predict'
include { UHVDB_CATHEADER       } from '../../../modules/local/uhvdb/catheader'

workflow IPHOP {

    take:
    fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    //-------------------------------------------
    // MODULE: IPHOP_DOWNLOAD
    // outputs:
    // - [ [ meta ], "iphop_db/" ]
    // steps:
    // - Download iphop's database (script)
    //--------------------------------------------
    IPHOP_DOWNLOAD()

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
        fna_gz,
        250
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fna", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: IPHOP_PREDICT
    // inputs:
    // - [ [ meta ], virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], *.iphop_genus.csv.gz ]
    // - [ [ meta ], *.iphop_genome.csv.gz ]
    // steps:
    // - Decompress (script)
    // - Create DB (script)
    // - Cleanup (script)
    //--------------------------------------------
    IPHOP_PREDICT(
        ch_split_fna_gz,
        IPHOP_DOWNLOAD.out.iphop_db
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *.iphop_genus.csv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_iphop.csv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = IPHOP_PREDICT.out.genus_csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'iphop_genus' ], csv_gz, 1, 'csv.gz' ] }
        .mix(IPHOP_PREDICT.out.genome_csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'iphop_genome' ], csv_gz, 1, 'csv.gz' ] })
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/iphop/"
    )

    emit:
    genus_tsv_gz = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'iphop_genus' }
    genome_tsv_gz = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'iphop_genome' }
}

