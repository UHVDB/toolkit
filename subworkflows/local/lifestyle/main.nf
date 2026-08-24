include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2/main'
include { BACPHLIP                      } from '../../../modules/local/bacphlip/main'
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader/main'
include { UHVDB_LIFESTYLE               } from '../../../modules/local/uhvdb/lifestyle/main'
include { rmEmptyFastAs; add_split      } from '../functions/main'

workflow LIFESTYLE {

    take:
    virus_fna_gz
    classify_tsv_gz
    pharokka_tsv_gz
    phold_tsv_gz
    empathi_csv_gz
    protein2hash_tsv_gz
    uhvdb_metadata_tsv_gz

    main:

    //
    // MODULE: Split sequences for BACPHLIP
    //
    SEQKIT_SPLIT2(
        rmEmptyFastAs(virus_fna_gz),
        1000
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastx
        .transpose()
        .map { meta, fastx ->
            [ add_split(meta, fastx.getName()), fastx ]
        }

    //
    // MODULE: Run BACPHLIP on split sequences
    //
    BACPHLIP(
        ch_split_fna_gz
    )

    //
    // MODULE: Combine BACPHLIP results
    //
    ch_catheader_input = BACPHLIP.out.tsv_gz
        .map { _meta, tsv_gz -> tsv_gz }
        .collect()
        .map { tsv_gz -> [ [ id: 'new_genomovars_bacphlip' ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input
    )

    //
    // MODULE: Combine BACPHLIP results with other lifestyle-related annotations and classify lifestyle
    //
    UHVDB_LIFESTYLE(
        UHVDB_CATHEADER.out.combined.map { _meta, tsv_gz -> [ [ id: 'new_genomovars' ], tsv_gz ] },
        classify_tsv_gz,
        pharokka_tsv_gz,
        phold_tsv_gz,
        empathi_csv_gz,
        protein2hash_tsv_gz,
        uhvdb_metadata_tsv_gz
    )

    emit:
    bacphlip_tsv_gz  = UHVDB_CATHEADER.out.combined
    lifestyle_tsv_gz = UHVDB_LIFESTYLE.out.tsv_gz
}
