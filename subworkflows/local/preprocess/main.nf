include { DEACON_INDEXFETCH } from '../../../modules/local/deacon/indexfetch'
include { SRACHA_FASTP_DEACON_SPRING } from '../../../modules/local/sracha_fastp_deacon_spring'
include { FASTP_DEACON_SPRING } from '../../../modules/local/fastp_deacon_spring'

workflow PREPROCESS {
    take:
    deacon_index_name   // string, name of deacon index
    fastqs              // channel: [ val(meta), [ read1.fastq.gz, read1.fastq.gz? ] ]
    sras                // channel: [ val(meta), sra ]

    main:
    def ch_preprocessed_spring = channel.empty()

    //
    // MODULE: Download deacon index
    //
    DEACON_INDEXFETCH(
        deacon_index_name
    )
    ch_deacon_idx = DEACON_INDEXFETCH.out.idx.first()

    //
    // MODULE: Download, QC, and remove human reads, then compress with spring
    //
    SRACHA_FASTP_DEACON_SPRING(
        sras,
        ch_deacon_idx
    )
    ch_preprocessed_spring = SRACHA_FASTP_DEACON_SPRING.out.spring
        .combine(SRACHA_FASTP_DEACON_SPRING.out.read_count, by:0)
        .map { meta, spring, read_count ->
            meta.single_end = (read_count == 1)
            return [ meta, spring ]
        }
        .mix(ch_preprocessed_spring)

    //
    // MODULE: QC reads, remove human reads, and compress with spring
    //
    FASTP_DEACON_SPRING(
        fastqs,
        ch_deacon_idx
    )
    ch_preprocessed_spring = ch_preprocessed_spring
        .mix(FASTP_DEACON_SPRING.out.spring)

    emit:
    spring = ch_preprocessed_spring
}
