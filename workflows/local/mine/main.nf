/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { CLASSIFY        } from '../../../subworkflows/local/classify'

workflow MINE {

    take:
    assembly_fna_gz // channel: [ [ meta ], assembly.fna.gz ]
    virus_fna_gz    // channel: [ [ meta ], virus.fna.gz ]

    main:

    //
    // SUBWORKFLOW: Classify viral sequences from an assembly
    //

    //
    // SUBWORKFLOW: Filter HQ and high-confidence viruses
    //

    // emit:
}
