include { SPACER_DOWNLOAD                 } from '../../../modules/local/spacer/download/main'
include { SPACEREXTRACTOR_CREATETARGETDB } from '../../../modules/local/spacerextractor/createtargetdb/main'
include { SPACEREXTRACTOR_MAPTOTARGET    } from '../../../modules/local/spacerextractor/maptotarget/main'
include { FIND_CONCATENATEHEADERS as FIND_CONCATENATEHEADERS_CRISPR     } from '../../../modules/local/find/concatenateheaders/main'
include { FIND_CONCATENATEHEADERS as FIND_CONCATENATEHEADERS_CRISPRHOST } from '../../../modules/local/find/concatenateheaders/main'
include { add_split                      } from '../functions/main'

workflow CRISPRHOST {

    take:
    fna_gz

    main:

    //
    // MODULE: Download CRISPR spacer database
    //
    SPACER_DOWNLOAD()

    //
    // MODULE: Create target database for spacer mapping
    //
    SPACEREXTRACTOR_CREATETARGETDB(
        fna_gz
    )

    //
    // MODULE: Align spacers to target database and determine taxonomy
    //
    SPACEREXTRACTOR_MAPTOTARGET(
        SPACER_DOWNLOAD.out.fna_gz.map { fna -> [ [ id: 'spacers' ], fna ] }.first(),
        SPACER_DOWNLOAD.out.tsv_gz.first(),
        SPACEREXTRACTOR_CREATETARGETDB.out.db
    )

    //
    // MODULE: Combine SpacerExtractor hits across all chunks
    //
    FIND_CONCATENATEHEADERS_CRISPR(
        SPACEREXTRACTOR_MAPTOTARGET.out.se_tsv_gz
            .map { _meta, tsv_gz -> tsv_gz }
            .collect()
            .map { tsv_gzs -> [ [ id: 'new_genomovars_crispr' ], tsv_gzs ] },
        1
    )

    //
    // MODULE: Combine CRISPR host consensus across all chunks
    //
    FIND_CONCATENATEHEADERS_CRISPRHOST(
        SPACEREXTRACTOR_MAPTOTARGET.out.crisprhost_tsv_gz
            .map { _meta, tsv_gz -> tsv_gz }
            .collect()
            .map { tsv_gzs -> [ [ id: 'new_genomovars_crisprhost' ], tsv_gzs ] },
        1
    )

    emit:
    crispr_tsv_gz     = FIND_CONCATENATEHEADERS_CRISPR.out.file_out
    crisprhost_tsv_gz = FIND_CONCATENATEHEADERS_CRISPRHOST.out.file_out
}
