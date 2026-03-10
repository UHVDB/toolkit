/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PHIST_BUILD       } from '../../../modules/local/phist/build'
include { PHIST_ARIA2C      } from '../../../modules/local/phist/aria2c'
include { UHVDB_PHISTHOST   } from '../../../modules/local/uhvdb/phisthost'
include { SEQKIT_GREP       } from '../../../modules/local/seqkit/grep'

workflow PHIST {

    take:
    fna_gz // channel: [ [ meta ], fna.gz ]

    main:

    //-------------------------------------------
    // MODULE: PHIST_BUILD
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], phist_db/ ]
    // steps:
    // - Decompress (script)
    // - Create DB (script)
    // - Cleanup (script)
    //--------------------------------------------
    PHIST_BUILD(
        fna_gz
    )

    //-------------------------------------------
    // MODULE: PHIST_ARIA2C
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], phist_db/ ]
    // steps:
    // - Create input file (script)
    // - Download genomes (script)
    // - Run phist (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    ch_host_fastas = channel.fromPath(params.bacterial_host_urls)
        .splitCsv(header: false, strip: true)
        .flatten()
        .collate(20000)
        .toList()
        .flatMap{ file -> file.withIndex() }
        .map { file, index ->
            [ [ id: 'chunk_' + index ], file ]
        }

    PHIST_ARIA2C(
        ch_host_fastas,
        PHIST_BUILD.out.kdb.first()
    )

    //-------------------------------------------
    // MODULE: UHVDB_PHISTHOST
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], uhvdb_phist.csv.gz ]
    // outputs:
    // - [ [ meta ], uhvdb_phisthost.tsv.gz ]
    // steps:
    // - Combine files (script)
    // - Identify consensus host (script)
    // - Extract no host viruses (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    UHVDB_PHISTHOST(
        PHIST_ARIA2C.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'phisthost' ], csv_gz ] }
    )

    //-------------------------------------------
    // MODULE: SEQKIT_GREP
    // inputs:
    // - [ [ meta ], uhvdb_phisthost.tsv.gz, virus.fna.gz ]
    // - boolean: false (whether to invert-match)
    // outputs:
    // - [ [ meta ], virus_nophisthost.fna.gz ]
    // steps:
    // - Extract patterns (script)
    // - Grep sequences (script)
    // - Cleanup (script)
    //--------------------------------------------
    SEQKIT_GREP(
        UHVDB_PHISTHOST.out.phisthost_tsv_gz.combine(fna_gz.map { _meta, fna_gz -> fna_gz }),
        true
    )

    emit:
    tsv_gz = UHVDB_PHISTHOST.out.phisthost_tsv_gz
    fna_gz = SEQKIT_GREP.out.fna_gz
}

