include { GENOMAD_DOWNLOADHALLMARKS } from '../../../modules/local/genomad/downloadhallmarks/main'
include { CSVTK_SEQKIT } from '../../../modules/local/csvtk_seqkit/main'
include { CSVTK_SEQKIT as CSVTK_SEQKIT_CONFIDENT } from '../../../modules/local/csvtk_seqkit/main'
include { GENOMAD_HMMSEARCH } from '../../../modules/local/genomad/hmmsearch/main'
include { rmEmptyFastAs } from '../functions/main'
workflow HCFILTER {

    take:
    hq_viruses_fna_gz
    classify_tsv_gz

    main:

    //
    // MODULE: Download hallmark HMMs and metadata from Genomad
    //
    GENOMAD_DOWNLOADHALLMARKS()

    //
    // MODULE: Extract uncertain viruses from HQ viruses
    //
    CSVTK_SEQKIT(
        classify_tsv_gz.join(rmEmptyFastAs(hq_viruses_fna_gz))
    )

    //
    // MODULE: Extract confident viruses from HQ viruses
    //
    CSVTK_SEQKIT_CONFIDENT(
        classify_tsv_gz.join(rmEmptyFastAs(hq_viruses_fna_gz))
    )

    //
    // MODULE: Run HMMsearch on uncertain viruses
    //
    GENOMAD_HMMSEARCH(
        rmEmptyFastAs(CSVTK_SEQKIT.out.fna_gz),
        GENOMAD_DOWNLOADHALLMARKS.out.hmm.collect(),
        GENOMAD_DOWNLOADHALLMARKS.out.tsv_gz.collect()
    )

    emit:
    fna_gz = GENOMAD_HMMSEARCH.out.fna_gz
        .map { meta, fna_gz ->
                meta.id = meta.id + "_uncertain"
                [ meta, fna_gz ]
        }
        .mix(CSVTK_SEQKIT_CONFIDENT.out.fna_gz)
    tsv_gz = GENOMAD_HMMSEARCH.out.tsv_gz
}

