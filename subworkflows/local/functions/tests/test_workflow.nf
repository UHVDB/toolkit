include { rmEmptyFastAs; rmEmptyTsvs; countFastAs; add_split; extractDigitBeforeExtension } from '../main'

workflow TEST_FUNCTIONS {
    take:
    ch_fastas
    ch_tsvs

    main:
    emit:
    nonempty_fastas = rmEmptyFastAs(ch_fastas)
    nonempty_tsvs   = rmEmptyTsvs(ch_tsvs)
    fasta_count     = countFastAs(ch_fastas)
}
