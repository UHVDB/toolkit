include { GENOMAD_DOWNLOADHALLMARKS } from '../../../modules/local/genomad/downloadhallmarks/main'
include { CSVTK_SEQKIT              } from '../../../modules/local/csvtk_seqkit/main'
include { GENOMAD_HMMSEARCH         } from '../../../modules/local/genomad/hmmsearch/main'
include { rmEmptyFastAs             } from '../functions/main'
workflow HCFILTER {

    take:
    hq_viruses_fna_gz

    main:

    //
    // MODULE: Download hallmark HMMs and metadata from Genomad
    //
    GENOMAD_DOWNLOADHALLMARKS()

    //
    // MODULE: Run HMMsearch on uncertain viruses
    //
    GENOMAD_HMMSEARCH(
        rmEmptyFastAs(hq_viruses_fna_gz.filter { meta, _fna_gz -> meta.confidence == 'uncertain' } ),
        GENOMAD_DOWNLOADHALLMARKS.out.hmm.collect(),
        GENOMAD_DOWNLOADHALLMARKS.out.tsv_gz.collect()
    )

    emit:
    fna_gz = rmEmptyFastAs(GENOMAD_HMMSEARCH.out.fna_gz)
        .mix(rmEmptyFastAs(hq_viruses_fna_gz.filter { meta, _fna_gz -> meta.confidence == 'confident' } ))
    tsv_gz = GENOMAD_HMMSEARCH.out.tsv_gz
}

