/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { SEQKIT_SPLIT2                     } from '../../../modules/local/seqkit/split2'
include { SPACEREXTRACTOR_CREATETARGETDB    } from '../../../modules/local/spacerextractor/createtargetdb'
include { SPACEREXTRACTOR_MAPTOTARGET       } from '../../../modules/local/spacerextractor/maptotarget'
include { UHVDB_CATHEADER                   } from '../../../modules/local/uhvdb/catheader'
include { SEQKIT_GREP                       } from '../../../modules/local/seqkit/grep'

workflow CRISPRHOST {

    take:
    fna_gz // channel: [ [ meta ], fna.gz ]

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
        fna_gz,
        params.crisprhost_split_size
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fna", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: SPACEREXTRACTOR_CREATETARGETDB
    // inputs:
    // - [ [ meta ], virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], target_db/ ]
    // steps:
    // - Decompress (script)
    // - Create DB (script)
    // - Cleanup (script)
    //--------------------------------------------
    SPACEREXTRACTOR_CREATETARGETDB(
        ch_split_fna_gz
    )

    //-------------------------------------------
    // MODULE: SPACEREXTRACTOR_MAPTOTARGET
    // inputs:
    // - [ [ neta ], virus.part_*.fna.gz ]
    // - [ [ meta ], target_db/ ]
    // outputs:
    // - [ [ meta ], *.spacerextractor.tsv.gz ]
    // - [ [ meta ], *.crisprhost.tsv.gz ]
    // steps:
    // - Map to target (script)
    // - Filter and get taxonomy (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    ch_spacer_fasta = channel.fromPath(params.spacer_fasta)
        .map { fasta -> [ [ id: 'spacers' ], fasta ] }
    SPACEREXTRACTOR_MAPTOTARGET(
        ch_spacer_fasta.collect(),
        SPACEREXTRACTOR_CREATETARGETDB.out.db
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *.crisprhost.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = SPACEREXTRACTOR_MAPTOTARGET.out.se_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'spacerextractor' ], tsv_gz, 1, 'tsv.gz' ] }
        .mix(SPACEREXTRACTOR_MAPTOTARGET.out.crisprhost_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'crisprhost' ], tsv_gz, 1, 'tsv.gz' ] })
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/crisprhost/"
    )

    //-------------------------------------------
    // MODULE: SEQKIT_GREP
    // inputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz, virus.fna.gz ]
    // - boolean: false (whether to invert-match)
    // outputs:
    // - [ [ meta ], virus_crisprhost.fna.gz ]
    // steps:
    // - Extract patterns (script)
    // - Grep sequences (script)
    // - Cleanup (script)
    //--------------------------------------------
    SEQKIT_GREP(
        UHVDB_CATHEADER.out.combined.combine(fna_gz.map { _meta, fna_gz -> fna_gz }),
        true
    )

    emit:
    tsv_gz = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'crisprhost' }
    fna_gz = SEQKIT_GREP.out.fna_gz
}

