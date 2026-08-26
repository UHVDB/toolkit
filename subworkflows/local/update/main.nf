include { UHVDB_METADATA                } from '../../../modules/local/uhvdb/metadata/main'
include { UHVDB_SYLPHTAX                } from '../../../modules/local/uhvdb/sylphtax/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_ICTVHITS } from '../../../modules/nf-core/find/concatenate/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_PROTEINS } from '../../../modules/nf-core/find/concatenate/main'
include { UHVDB_CONCATCRISPR            } from '../../../modules/local/uhvdb/concatcrispr/main'
include { UHVDB_CONCATPHIST             } from '../../../modules/local/uhvdb/concatphist/main'

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
    lifestyle_tsv_gz
    uhvdb_metadata_tsv_gz
    uhvdb_protein_annotations
    protein_faa_gz
    new_proteins_faa_gz
    old_proteins_faa_gz
    ictv_hits_tsv_gz
    crispr_tsv_gz
    phist_tsv_gz
    uhvdb_ictv_hits_tsv_gz
    uhvdb_crispr_parquet
    uhvdb_phist_parquet

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
        lifestyle_tsv_gz,
        uhvdb_metadata_tsv_gz,
        uhvdb_protein_annotations,
        protein_faa_gz.map { _meta, faa -> faa }.flatten().collect()
    )

    //
    // MODULE: Build sylph-tax metadata for species representatives
    //
    UHVDB_SYLPHTAX(
        UHVDB_METADATA.out.tsv_gz
    )

    //
    // MODULE: Combine new unique proteins with existing UHVDB proteins
    //
    FIND_CONCATENATE_PROTEINS(
        new_proteins_faa_gz
            .map { _meta, faa_gz -> faa_gz }
            .mix(
                old_proteins_faa_gz.map { faa_gz ->
                    faa_gz instanceof List ? faa_gz[0] : faa_gz
                }
            )
            .collect()
            .map { faa_gzs -> [ [ id: 'uhvdb_proteins' ], faa_gzs ] }
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
    // MODULE: Combine new and existing CRISPR hit tables into parquet
    //
    UHVDB_CONCATCRISPR(
        crispr_tsv_gz
            .mix(
                uhvdb_crispr_parquet.map { parquet ->
                    [ [ id: 'uhvdb_crispr' ], parquet instanceof List ? parquet[0] : parquet ]
                }
            )
            .map { _meta, hits -> hits }
            .collect()
            .map { hits -> [ [ id: 'uhvdb_crispr' ], hits ] }
    )

    //
    // MODULE: Combine new and existing PHIST hit tables into parquet
    //
    UHVDB_CONCATPHIST(
        phist_tsv_gz
            .mix(
                uhvdb_phist_parquet.map { parquet ->
                    [ [ id: 'uhvdb_phist' ], parquet instanceof List ? parquet[0] : parquet ]
                }
            )
            .map { _meta, hits -> hits }
            .collect()
            .map { hits -> [ [ id: 'uhvdb_phist' ], hits ] }
    )

    emit:
    metadata_tsv_gz                 = UHVDB_METADATA.out.tsv_gz
    protein_annotations_parquet     = UHVDB_METADATA.out.protein_annotations_parquet
    metadata_sylphtax_tsv_gz        = UHVDB_SYLPHTAX.out.tsv_gz
    proteins_faa_gz                 = FIND_CONCATENATE_PROTEINS.out.file_out
    ictv_hits_tsv_gz                = FIND_CONCATENATE_ICTVHITS.out.file_out
    crispr_parquet                  = UHVDB_CONCATCRISPR.out.parquet
    phist_parquet                   = UHVDB_CONCATPHIST.out.parquet
}
