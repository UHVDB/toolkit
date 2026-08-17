include { UHVDB_METADATA                } from '../../../modules/local/uhvdb/metadata/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_ICTVHITS } from '../../../modules/nf-core/find/concatenate/main'
include { FIND_CONCATENATEHEADERS as FIND_CONCATENATEHEADERS_CRISPRHITS } from '../../../modules/local/find/concatenateheaders/main'
include { FIND_CONCATENATEHEADERS as FIND_CONCATENATEHEADERS_PHISTHITS } from '../../../modules/local/find/concatenateheaders/main'

workflow UPDATE {

    take:
    seqhasher_tsv_gz
    mapping_tsv_gz
    classify_tsv_gz
    hqfilter_tsv_gz
    hcfilter_tsv_gz
    genomovar_info_tsv_gz
    species_info_tsv_gz
    aaicluster_tsv_gz
    taxonomy_tsv_gz
    crisprhost_tsv_gz
    phisthost_tsv_gz
    proteinhash_tsv_gz
    bakta_tsv_gz
    foldseek_tsv_gz
    interproscan_tsv_gz
    card_tsv_gz
    vfdb_tsv_gz
    pharokka_tsv_gz
    phold_tsv_gz
    empathi_csv_gz
    uhvdb_metadata_tsv_gz
    uhvdb_protein_annotations_tsv_gz
    ictv_hits_tsv_gz
    crispr_tsv_gz
    phist_tsv_gz
    uhvdb_ictv_hits_tsv_gz
    uhvdb_crispr_tsv_gz
    uhvdb_phist_tsv_gz

    main:

    //
    // MODULE: Build merged metadata and protein annotation tables
    //
    UHVDB_METADATA(
        seqhasher_tsv_gz,
        mapping_tsv_gz,
        classify_tsv_gz,
        hqfilter_tsv_gz,
        hcfilter_tsv_gz,
        genomovar_info_tsv_gz,
        species_info_tsv_gz,
        aaicluster_tsv_gz,
        taxonomy_tsv_gz,
        crisprhost_tsv_gz,
        phisthost_tsv_gz,
        proteinhash_tsv_gz,
        bakta_tsv_gz,
        foldseek_tsv_gz,
        interproscan_tsv_gz,
        card_tsv_gz,
        vfdb_tsv_gz,
        pharokka_tsv_gz,
        phold_tsv_gz,
        empathi_csv_gz,
        uhvdb_metadata_tsv_gz,
        uhvdb_protein_annotations_tsv_gz
    )

    //
    // MODULE: Combine new and existing ICTV hit tables (headerless)
    //
    FIND_CONCATENATE_ICTVHITS(
        ictv_hits_tsv_gz
            .mix(
                uhvdb_ictv_hits_tsv_gz.map { tsv_gz ->
                    [ [ id: 'uhvdb_ictv_hits' ], tsv_gz instanceof List ? tsv_gz[0] : tsv_gz ]
                }
            )
            .map { _meta, tsv_gz -> tsv_gz }
            .collect()
            .map { tsv_gzs -> [ [ id: 'uhvdb_ictv_hits' ], tsv_gzs ] }
    )

    //
    // MODULE: Combine new and existing CRISPR hit tables
    //
    FIND_CONCATENATEHEADERS_CRISPRHITS(
        crispr_tsv_gz
            .mix(
                uhvdb_crispr_tsv_gz.map { tsv_gz ->
                    [ [ id: 'uhvdb_crispr' ], tsv_gz instanceof List ? tsv_gz[0] : tsv_gz ]
                }
            )
            .map { _meta, tsv_gz -> tsv_gz }
            .collect()
            .map { tsv_gzs -> [ [ id: 'uhvdb_crispr' ], tsv_gzs ] },
        1
    )

    //
    // MODULE: Combine new and existing PHIST hit tables
    //
    FIND_CONCATENATEHEADERS_PHISTHITS(
        phist_tsv_gz
            .mix(
                uhvdb_phist_tsv_gz.map { tsv_gz ->
                    [ [ id: 'uhvdb_phist' ], tsv_gz instanceof List ? tsv_gz[0] : tsv_gz ]
                }
            )
            .map { _meta, tsv_gz -> tsv_gz }
            .collect()
            .map { tsv_gzs -> [ [ id: 'uhvdb_phist' ], tsv_gzs ] },
        1
    )

    emit:
    metadata_tsv_gz             = UHVDB_METADATA.out.tsv_gz
    protein_annotations_tsv_gz  = UHVDB_METADATA.out.protein_annotations_tsv_gz
    ictv_hits_tsv_gz            = FIND_CONCATENATE_ICTVHITS.out.file_out
    crispr_tsv_gz               = FIND_CONCATENATEHEADERS_CRISPRHITS.out.file_out
    phist_tsv_gz                = FIND_CONCATENATEHEADERS_PHISTHITS.out.file_out
}
