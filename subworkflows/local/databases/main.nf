/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { CHECKV_DOWNLOAD           } from '../../../modules/local/checkv/download'
include { GENOMAD_DOWNLOADDATABASE  } from '../../../modules/local/genomad/downloaddatabase'

workflow DATABASES {

    main:

    //-------------------------------------------
    // MODULE: GENOMAD_DOWNLOADDATABASE
    // outputs:
    // - [ [ meta ], "genomad_db/" ]
    // steps:
    // - Download genomad's database (script)
    //--------------------------------------------
    GENOMAD_DOWNLOADDATABASE()

    //-------------------------------------------
    // MODULE: CHECKV_DOWNLOAD
    // outputs:
    // - [ [ meta ], "checkv_db/" ]
    // steps:
    // - Download database (script)
    //--------------------------------------------
    if ( params.checkv_db ) {
        ch_checkv_db = channel.fromPath("${params.checkv_db}").first()
    } else {
        CHECKV_DOWNLOAD()
        ch_checkv_db = CHECKV_DOWNLOAD.out.checkv_db
    }
    

    emit:
    genomad_db  = GENOMAD_DOWNLOADDATABASE.out.genomad_db
    checkv_db   = ch_checkv_db
}

