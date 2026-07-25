include { SRACHA_FASTP_DEACON_MEGAHIT   } from '../../../modules/local/sracha_fastp_deacon_megahit/main'
include { FASTP_DEACON_MEGAHIT          } from '../../../modules/local/fastp_deacon_megahit/main'

workflow ASSEMBLY {
    take:
    reads       // channel: [ [ meta ], read_1, read_2 ]
    sras        // channel: [ [ meta ], sra ]
    deacon_idx  // channel: [ deacon_idx ]

    main:

    //
    // MODULE: Download, preprocess, and assemble reads
    //
    SRACHA_FASTP_DEACON_MEGAHIT(
        sras,
        deacon_idx
    )
    ch_fna_gz = SRACHA_FASTP_DEACON_MEGAHIT.out.fna_gz

    //
    // MODULE: Preprocess and assemble reads
    //
    FASTP_DEACON_MEGAHIT(
        reads,
        deacon_idx
    )
    ch_fna_gz = ch_fna_gz.mix(FASTP_DEACON_MEGAHIT.out.fna_gz)


    emit:
    fna_gz = ch_fna_gz
}