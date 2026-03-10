/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { UHVDB_PRUNE   } from '../../../modules/local/uhvdb/prune'
include { MCL           } from '../../../modules/local/mcl'

workflow MCLCLUSTER {

    take:
    matrix_clusters         // channel: [ [ meta ], matrix.tsv.gz, clusters.mcl.gz ]
    similarity_threshold    // val: float

    main:

    //-------------------------------------------
    // MODULE: UHVDB_PRUNE
    // inputs:
    // - [ [ meta ], matrix.tsv.gz ]
    // - [ [ meta ], clusters.mcl.gz ]
    // - similarity_threshold
    // outputs:
    // - [ [ meta ], matrix.pruned.tsv.gz ]
    // steps:
    // - Prune graph (script)
    // - Compress (script)
    //--------------------------------------------
    UHVDB_PRUNE(
        matrix_clusters,
        similarity_threshold
    )

    //-------------------------------------------
    // MODULE: MCL_MCL
    // inputs:
    // - [ [ meta ], aaicluster.pruned.tsv.gz ]
    // outputs:
    // - [ [ meta ], aaicluster.mcl.gz ]
    // steps:
    // - Decompress (script)
    // - Run MCL (script)
    //--------------------------------------------
    MCL(
        UHVDB_PRUNE.out.tsv_gz,
    )

    emit:
    mcl_gz = MCL.out.mcl_gz
}
