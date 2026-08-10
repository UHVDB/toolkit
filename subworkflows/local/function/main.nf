include { BAKTA_DOWNLOAD                } from '../../../modules/local/bakta/download/main'
include { BAKTA_GETMOD                  } from '../../../modules/local/bakta/getmod/main'
include { BAKTA_PROTEINS                } from '../../../modules/local/bakta/proteins/main'
include { CARD_DIAMOND                  } from '../../../modules/local/card/diamond/main'
include { CARD_DOWNLOAD                 } from '../../../modules/local/card/download/main'
include { EMPATHI_INSTALL               } from '../../../modules/local/empathi/install/main'
include { EMPATHI_EMPATHI               } from '../../../modules/local/empathi/empathi/main'
include { EMPATHI_ONLYEMBEDDINGS        } from '../../../modules/local/empathi/onlyembeddings/main'
include { FOLDSEEK_CREATEDB             } from '../../../modules/local/foldseek/createdb/main'
include { FOLDSEEK_CREATEDBPROSTT5      } from '../../../modules/local/foldseek/createdbprostt5/main'
include { FOLDSEEK_EASYSEARCH           } from '../../../modules/local/foldseek/easysearch/main'
include { INTERPROSCAN_DOWNLOAD         } from '../../../modules/local/interproscan/download/main'
include { INTERPROSCAN_INTERPROSCAN     } from '../../../modules/local/interproscan/interproscan/main'
include { PHAROKKA_INSTALLDATABASES     } from '../../../modules/local/pharokka/installdatabases/main'
include { PHAROKKA_PROTEINS             } from '../../../modules/local/pharokka/proteins/main'
include { PHOLD_INSTALL                 } from '../../../modules/local/phold/install/main'
include { PHOLD_PREDICT                 } from '../../../modules/local/phold/predict/main'
include { PHOLD_COMPARE                 } from '../../../modules/local/phold/compare/main'
include { SEQKIT_FX2TAB                 } from '../../../modules/local/seqkit/fx2tab/main'
include { SEQKIT_SPLIT2 as PROTEIN_SEQKIT_SPLIT2 } from '../../../modules/local/seqkit/split2/main'
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader/main'
include { UHVDB_CATNOHEADER             } from '../../../modules/local/uhvdb/catnoheader/main'
include { UHVDB_PROTEINHASH             } from '../../../modules/local/uhvdb/proteinhash/main'
include { UNIREF50VIRUS                 } from '../../../modules/local/uniref50virus/main'
include { VFDB_DIAMOND                  } from '../../../modules/local/vfdb/diamond/main'
include { VFDB_DOWNLOAD                 } from '../../../modules/local/vfdb/download/main'
include { rmEmptyFastAs; add_split      } from '../functions/main'

workflow FUNCTION {

    take:
    virus_faa_gz                      // channel: [ meta, faa.gz ]
    uhvdb_protein_annotations_tsv_gz  // channel: uhvdb_protein_annotations.tsv.gz

    main:

    //
    // MODULE: Download Bakta database and setup
    //
    BAKTA_DOWNLOAD()

    //
    // MODULE: Download modified Bakta repo
    //
    BAKTA_GETMOD(params.bakta_mod_url)

    //
    // MODULE: Download CARD and create DIAMOND DB
    //
    CARD_DOWNLOAD()

    //
    // MODULE: Create a FoldSeek database for viral structures
    //
    ch_virus_structures = channel.fromPath(params.virus_structures).collect()
    FOLDSEEK_CREATEDB(ch_virus_structures)

    //
    // MODULE: Download InterProScan DB and setup
    //
    INTERPROSCAN_DOWNLOAD()

    //
    // MODULE: Install Empathi models
    //
    EMPATHI_INSTALL()

    //
    // MODULE: Install Pharokka DBs and setup
    //
    PHAROKKA_INSTALLDATABASES()

    //
    // MODULE: Install Phold DB
    //
    PHOLD_INSTALL()

    //
    // MODULE: Download UniRef50 virus sequences
    //
    UNIREF50VIRUS()

    //
    // MODULE: Download VFDB database
    //
    VFDB_DOWNLOAD()

    //
    // MODULE: Hash existing predicted proteins (no re-prediction)
    //
    SEQKIT_FX2TAB(
        rmEmptyFastAs(virus_faa_gz)
    )

    ch_unique_input = SEQKIT_FX2TAB.out.tsv_gz
        .map { _meta, tsv_gz -> tsv_gz }
        .collect()
        .map { tsv_gzs -> [ [ id: 'new_proteins' ], tsv_gzs ] }

    UHVDB_PROTEINHASH(
        ch_unique_input,
        uhvdb_protein_annotations_tsv_gz.first()
    )

    //
    // MODULE: Split new unique proteins into chunks for parallel annotation
    //
    PROTEIN_SEQKIT_SPLIT2(
        UHVDB_PROTEINHASH.out.faa_gz,
        params.function_protein_split_size
    )
    ch_split_faa_gz = PROTEIN_SEQKIT_SPLIT2.out.fastx
        .transpose()
        .map { meta, fastx ->
            [ add_split(meta, fastx.getName()), fastx ]
        }

    //
    // MODULE: Run Bakta proteins module to annotate predicted proteins
    //
    BAKTA_PROTEINS(
        ch_split_faa_gz,
        BAKTA_DOWNLOAD.out.db.collect(),
        UNIREF50VIRUS.out.faa_gz.collect(),
        BAKTA_GETMOD.out.bakta_mod.collect()
    )

    //
    // MODULE: Convert AA to 3DI for FoldSeek searching
    //
    FOLDSEEK_CREATEDBPROSTT5(
        rmEmptyFastAs(BAKTA_PROTEINS.out.faa_gz),
        FOLDSEEK_CREATEDB.out.weights.collect()
    )

    //
    // MODULE: Search predicted proteins against viral structure database with FoldSeek
    //
    FOLDSEEK_EASYSEARCH(
        FOLDSEEK_CREATEDBPROSTT5.out.db.combine(BAKTA_PROTEINS.out.faa_gz, by: 0),
        FOLDSEEK_CREATEDB.out.db.collect()
    )

    //
    // MODULE: Run InterProScan on FoldSeek no-hit proteins
    //
    INTERPROSCAN_INTERPROSCAN(
        rmEmptyFastAs(FOLDSEEK_EASYSEARCH.out.faa_gz),
        INTERPROSCAN_DOWNLOAD.out.db.collect()
    )

    //
    // MODULE: Run DIAMOND against CARD database to identify AMR genes
    //
    CARD_DIAMOND(
        ch_split_faa_gz,
        CARD_DOWNLOAD.out.dmnd.collect()
    )

    //
    // MODULE: Run DIAMOND against VFDB database to identify virulence factors
    //
    VFDB_DIAMOND(
        ch_split_faa_gz,
        VFDB_DOWNLOAD.out.dmnd.collect()
    )

    //
    // MODULE: Run Pharokka to identify PHROGS using HMMs
    //
    PHAROKKA_PROTEINS(
        ch_split_faa_gz,
        PHAROKKA_INSTALLDATABASES.out.db.collect()
    )

    //
    // MODULE: Convert Pharokka no-hit proteins to 3DI for Phold
    //
    PHOLD_PREDICT(
        PHAROKKA_PROTEINS.out.faa_gz,
        PHOLD_INSTALL.out.db.collect()
    )

    //
    // MODULE: Identify PHROGs using Phold foldseek compare
    //
    PHOLD_COMPARE(
        PHAROKKA_PROTEINS.out.faa_gz.combine(PHOLD_PREDICT.out.predict, by: 0),
        PHOLD_INSTALL.out.db.collect()
    )

    //
    // MODULE: Convert predicted proteins to embeddings with Empathi
    //
    EMPATHI_ONLYEMBEDDINGS(
        ch_split_faa_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //
    // MODULE: Get Empathi annotations based on embedding similarity
    //
    EMPATHI_EMPATHI(
        EMPATHI_ONLYEMBEDDINGS.out.csv_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //
    // MODULE: Combine header-aware annotation tables
    //
    ch_catheader_input = (
        BAKTA_PROTEINS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_bakta' ], tsv_gz, 6, 'tsv.gz' ] }
        .mix(EMPATHI_EMPATHI.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id: 'new_proteins_empathi' ], csv_gz, 1, 'csv.gz' ] })
        .mix(PHAROKKA_PROTEINS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_pharokka' ], tsv_gz, 1, 'tsv.gz' ] })
        .mix(PHOLD_COMPARE.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_phold' ], tsv_gz, 1, 'tsv.gz' ] })
    )
    UHVDB_CATHEADER(ch_catheader_input)

    //
    // MODULE: Combine headerless annotation tables
    //
    ch_catnoheader_input = (
        FOLDSEEK_EASYSEARCH.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_foldseek' ], tsv_gz, 'tsv.gz' ] }
        .mix(INTERPROSCAN_INTERPROSCAN.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_interproscan' ], tsv_gz, 'tsv.gz' ] })
        .mix(CARD_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_card' ], tsv_gz, 'tsv.gz' ] })
        .mix(VFDB_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id: 'new_proteins_vfdb' ], tsv_gz, 'tsv.gz' ] })
    )
    UHVDB_CATNOHEADER(ch_catnoheader_input)

    emit:
    protein2hash_tsv_gz = UHVDB_PROTEINHASH.out.tsv_gz
    protein_faa_gz      = UHVDB_PROTEINHASH.out.faa_gz
    bakta_tsv_gz        = UHVDB_CATHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_bakta' }
    foldseek_tsv_gz     = UHVDB_CATNOHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_foldseek' }
    interproscan_tsv_gz = UHVDB_CATNOHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_interproscan' }
    card_tsv_gz         = UHVDB_CATNOHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_card' }
    vfdb_tsv_gz         = UHVDB_CATNOHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_vfdb' }
    pharokka_tsv_gz     = UHVDB_CATHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_pharokka' }
    phold_tsv_gz        = UHVDB_CATHEADER.out.combined.filter { meta, _tsv_gz -> meta.id == 'new_proteins_phold' }
    empathi_csv_gz      = UHVDB_CATHEADER.out.combined.filter { meta, _csv_gz -> meta.id == 'new_proteins_empathi' }
}
