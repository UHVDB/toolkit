/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// FUNCTIONS
def rmEmptyFastAs(ch_fastas) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: 1 ) > 0
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmEmptyFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmEmptyFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { BAKTA_DOWNLOAD                } from '../../../modules/local/bakta/download'
include { BAKTA_GETMOD                  } from '../../../modules/local/bakta/getmod'
include { BAKTA_PROTEINS                } from '../../../modules/local/bakta/proteins'
include { CARD_DIAMOND                  } from '../../../modules/local/card/diamond'
include { CARD_DOWNLOAD                 } from '../../../modules/local/card/download'
include { DEFENSEFINDER_UPDATE          } from '../../../modules/local/defensefinder/update'
include { DEFENSEFINDER_RUN             } from '../../../modules/local/defensefinder/run'
include { DGRSCAN                       } from '../../../modules/local/dgrscan'
include { EMPATHI_INSTALL               } from '../../../modules/local/empathi/install'
include { EMPATHI_EMPATHI               } from '../../../modules/local/empathi/empathi'
include { EMPATHI_ONLYEMBEDDINGS        } from '../../../modules/local/empathi/onlyembeddings'
include { FOLDSEEK_CREATEDB             } from '../../../modules/local/foldseek/createdb'
include { FOLDSEEK_CREATEDBPROSTT5      } from '../../../modules/local/foldseek/createdbprostt5'
include { FOLDSEEK_EASYSEARCH           } from '../../../modules/local/foldseek/easysearch'
include { INTERPROSCAN_DOWNLOAD         } from '../../../modules/local/interproscan/download'
include { INTERPROSCAN_INTERPROSCAN     } from '../../../modules/local/interproscan/interproscan'
include { PHAROKKA_INSTALLDATABASES     } from '../../../modules/local/pharokka/installdatabases'
include { PHAROKKA_PROTEINS             } from '../../../modules/local/pharokka/proteins'
include { PHOLD_INSTALL                 } from '../../../modules/local/phold/install'
include { PHOLD_PREDICT                 } from '../../../modules/local/phold/predict'
include { PHOLD_COMPARE                 } from '../../../modules/local/phold/compare'
include { PYRODIGALGV                   } from '../../../modules/local/pyrodigalgv'
include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2'
include { SEQKIT_SPLIT2 as PROTEIN_SEQKIT_SPLIT2 } from '../../../modules/local/seqkit/split2'
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER             } from '../../../modules/local/uhvdb/catnoheader'
include { UHVDB_GCODESPLIT              } from '../../../modules/local/uhvdb/gcodesplit/main'
include { UHVDB_PROTEINHASH             } from '../../../modules/local/uhvdb/proteinhash'
include { UNIREF50VIRUS                 } from '../../../modules/local/uniref50virus'
include { VFDB_DIAMOND                  } from '../../../modules/local/vfdb/diamond'
include { VFDB_DOWNLOAD                 } from '../../../modules/local/vfdb/download'

workflow FUNCTION {

    take:
    virus_fna_gz            // channel: [ [ meta ], virus.split.fna.gz ]
    virus_summary_tsv_gz    // channel: [ [ meta ], virus.summary.tsv.gz ]

    main:

    //-------------------------------------------
    // MODULE: BAKTA_DOWNLOAD
    // outputs:
    // - [ [ meta ], "bakta_db/" ]
    // steps:
    // - Download bakta's database (script)
    //--------------------------------------------
    BAKTA_DOWNLOAD()

    //-------------------------------------------
    // MODULE: BAKTA_GETMOD
    // outputs:
    // - [ [ meta ], "bakta_repo/" ]
    // steps:
    // - Download modified bakta repo(script)
    //--------------------------------------------
    BAKTA_GETMOD(params.bakta_mod_url)

    //-------------------------------------------
    // MODULE: CARD_DOWNLOAD
    // outputs:
    // - [ [ meta ], "card_db.dmnd" ]
    // steps:
    // - Download CARD proteins (script)
    // - Create DIAMOND DB (script)
    // - CLeanup (script)
    //--------------------------------------------
    CARD_DOWNLOAD()

    //-------------------------------------------
    // MODULE: DEFENSEFINDER_UPDATE
    // outputs:
    // - [ [ meta ], "defensefinder_db" ]
    // steps:
    // - Download DefenseFinder DB (script)
    // - Fix download (script)
    //--------------------------------------------
    DEFENSEFINDER_UPDATE()

    //-------------------------------------------
    // MODULE: FOLDSEEK_CREATEDB
    // outputs:
    // - [ [ meta ], "foldseek_db" ]
    // steps:
    // - Create foldseek DB (script)
    // - Download weights (script)
    // - Cleanup (script)
    //--------------------------------------------
    ch_virus_structures = channel.fromPath( params.virus_structures ).collect()
    FOLDSEEK_CREATEDB(ch_virus_structures)

    //-------------------------------------------
    // MODULE: INTERPROSCAN_DOWNLOAD
    // outputs:
    // - [ [ meta ], "interproscan_db" ]
    // steps:
    // - Download DB (script)
    // - Check md5sum (script)
    // - Extract (script)
    // - Setup (script)
    //--------------------------------------------
    INTERPROSCAN_DOWNLOAD()

    //-------------------------------------------
    // MODULE: EMPATHI_INSTALL
    // outputs:
    // - [ [ meta ], "empathi_models" ]
    // steps:
    // - Install git-lfs (script)
    // - Clone empathi (script)
    // - Install empathi (script)
    //--------------------------------------------
    EMPATHI_INSTALL()

    //-------------------------------------------
    // MODULE: PHAROKKA_INSTALLDATABASES
    // outputs:
    // - [ [ meta ], "pharokka_db" ]
    // steps:
    // - Download DB (script)
    //--------------------------------------------
    PHAROKKA_INSTALLDATABASES()

    //-------------------------------------------
    // MODULE: PHOLD_INSTALL
    // outputs:
    // - [ [ meta ], "phold_db" ]
    // steps:
    // - Download DB (script)
    //--------------------------------------------
    PHOLD_INSTALL()

    //
    // MODULE: Download UniRef50 virus sequences
    //
    UNIREF50VIRUS()

    //
    // MODULE: Download VFDB database
    //
    VFDB_DOWNLOAD()

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.fna.gz ... ] ]
    // steps:
    // - Split sequences (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        virus_fna_gz,
        1000
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fasta", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: PYRODIGALGV
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.pyrodigalgv.tsv.gz ] ]
    // steps:
    // - Run pyrodigal-gv (script)
    // - Convert to TSV (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    PYRODIGALGV(
        ch_split_fna_gz
    )

    //-------------------------------------------
    // MODULE: UHVDB_UNIQUEHASH
    // inputs:
    // - [ [ meta ], [ virus.part_*.pyrodigalgv.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], virus.unique.tsv.gz ]
    // - [ [ meta ], virus.unique.faa.gz ]
    // steps:
    // - Concatenate TSVs (script)
    // - Identify unique hashes (script)
    // - Write out tsv (script)
    // - Write out fasta (script)
    // - Cleanup (script)
    //-------------------------------------------
    if ( !file("${params.uhvdb_dir}/protein_hash.tsv.gz").exists() ) {
        ch_uhvdb_prothash_tsv_gz = channel.of([])
    } else {
        ch_uhvdb_prothash_tsv_gz = channel.fromPath("${params.uhvdb_dir}/protein_hash.tsv.gz")
            .map { tsv_gz -> [ tsv_gz ] }
    }

    ch_unique_input = PYRODIGALGV.out.tsv_gz
        .map { _meta, tsv_gz -> [ tsv_gz ] }
        .collect()
        .map { tsv_gzs -> [ [ id:'pyrodigalgv' ], tsv_gzs ] }

    UHVDB_PROTEINHASH(
        ch_unique_input,
        ch_uhvdb_prothash_tsv_gz.first(),
        "${params.output_dir}/${params.new_release_id}/uhvdb/function/",
    )

    //-------------------------------------------
    // MODULE: PROTEIN_SEQKIT_SPLIT2
    // inputs:
    // - [ [ meta ], virus.unique.faa.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.faa.gz ... ] ]
    // steps:
    // - Split sequences (script)
    //--------------------------------------------
    PROTEIN_SEQKIT_SPLIT2(
        UHVDB_PROTEINHASH.out.faa_gz,
        100000
    )
    ch_split_faa_gz = PROTEIN_SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, faa_gzs -> faa_gzs }
        .flatten()
        .map { faa_gz ->
            [ [ id: faa_gz.getBaseName().replace(".faa", "") ], faa_gz ]
        }

    //-------------------------------------------
    // MODULE: BAKTA_PROTEINS
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // outputs:
    // - [ [ meta ], virus.part_*.tsv.gz ]
    // - [ [ meta ], virus.part_*.faa.gz ]
    // - [ [ meta ], virus.part_*.nohit.faa.gz ]
    // steps:
    // - Run Bakta (script)
    // - Identify proteins without hits (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    BAKTA_PROTEINS(
        ch_split_faa_gz,
        BAKTA_DOWNLOAD.out.db.collect(),
        UNIREF50VIRUS.out.faa_gz.collect(),
        BAKTA_GETMOD.out.bakta_mod.collect()
    )

    //-------------------------------------------
    // MODULE: FOLDSEEK_CREATEDBPROSTT5
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // outputs:
    // - [ [ meta ], virus.part_*.3di_db* ]
    // steps:
    // - Convert AA to 3Di (script)
    //--------------------------------------------
    FOLDSEEK_CREATEDBPROSTT5(
        rmEmptyFastAs(BAKTA_PROTEINS.out.faa_gz),
        FOLDSEEK_CREATEDB.out.weights.collect()
    )

    //-------------------------------------------
    // MODULE: FOLDSEEK_EASYSEARCH
    // inputs:
    // - [ [ meta ], virus.part_*.3di_db* ]
    // - [ foldseek_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.3di_db* ]
    // steps:
    // - Run foldseek (script)
    // - Extract no hit proteins (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    FOLDSEEK_EASYSEARCH(
        FOLDSEEK_CREATEDBPROSTT5.out.db.combine(BAKTA_PROTEINS.out.faa_gz, by:0),
        FOLDSEEK_CREATEDB.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: INTERPROSCAN
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ interproscan_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.3di_db* ]
    // steps:
    // - Decompress (script)
    // - Run InterProScan (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    INTERPROSCAN_INTERPROSCAN(
        rmEmptyFastAs(FOLDSEEK_EASYSEARCH.out.faa_gz),
        INTERPROSCAN_DOWNLOAD.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: DEFENSEFINDER_RUN
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ defensefinder_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.systems.tsv.gz ]
    // steps:
    // - Run DefenseFinder (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    DEFENSEFINDER_RUN(
        ch_split_faa_gz,
        DEFENSEFINDER_UPDATE.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: DGRSCAN
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ defensefinder_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.systems.tsv.gz ]
    // steps:
    // - Decompress (script)
    // - Run DGRscan (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    // DGRSCAN(
    //     ch_split_fna_gz
    // )

    //-------------------------------------------
    // MODULE: CARD_DIAMOND
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ card.dmnd ]
    // outputs:
    // - [ [ meta ], virus.part_*.card.tsv.gz ]
    // steps:
    // - Run DIAMOND (script)
    // - Compress (script)
    //--------------------------------------------
    CARD_DIAMOND(
        ch_split_faa_gz,
        CARD_DOWNLOAD.out.dmnd.collect()
    )

    //-------------------------------------------
    // MODULE: VFDB_DIAMOND
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ card.dmnd ]
    // outputs:
    // - [ [ meta ], virus.part_*.vfdb.tsv.gz ]
    // steps:
    // - Run DIAMOND (script)
    // - Compress (script)
    //--------------------------------------------
    VFDB_DIAMOND(
        ch_split_faa_gz,
        VFDB_DOWNLOAD.out.dmnd.collect()
    )

    //-------------------------------------------
    // MODULE: PHAROKKA_PROTEINS
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ pharokka_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.pharokka.tsv.gz ]
    // steps:
    // - Decompress (script)
    // - Run DGRscan (script)
    // - Extract no hit proteins (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    PHAROKKA_PROTEINS(
        ch_split_faa_gz,
        PHAROKKA_INSTALLDATABASES.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: PHOLD_PREDICT
    // inputs:
    // - [ [ meta ], virus.pharokka_nohit.part_*.faa.gz ]
    // - [ phold_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.phold/ ]
    // steps:
    // - Decompress (script)
    // - Run Phold predict (script)
    // - Cleanup (script)
    //--------------------------------------------
    PHOLD_PREDICT(
        PHAROKKA_PROTEINS.out.faa_gz,
        PHOLD_INSTALL.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: PHOLD_COMPARE
    // inputs:
    // - [ [ meta ], virus.part_*.phold/ ]
    // - [ phold_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.phold/ ]
    // steps:
    // - Decompress (script)
    // - Run Phold compare (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    PHOLD_COMPARE(
        PHAROKKA_PROTEINS.out.faa_gz.combine(PHOLD_PREDICT.out.predict, by:0),
        PHOLD_INSTALL.out.db.collect()
    )

    //-------------------------------------------
    // MODULE: EMPATHI_ONLYEMBEDDINGS
    // inputs:
    // - [ [ meta ], virus.unique.part_*.faa.gz ]
    // - [ empathi_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.empathi.csv.gz ]
    // steps:
    // - Setup (script)
    // - Run Empathi (script)
    // - Compress (script)
    //--------------------------------------------
    EMPATHI_ONLYEMBEDDINGS(
        ch_split_faa_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //-------------------------------------------
    // MODULE: EMPATHI_ONLYEMBEDDINGS
    // inputs:
    // - [ [ meta ], virus.part_*.empathi.csv.gz ]
    // - [ empathi_db ]
    // outputs:
    // - [ [ meta ], virus.part_*.empathi.csv.gz ]
    // steps:
    // - Decompress (script)
    // - Run Empathi (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    EMPATHI_EMPATHI(
        EMPATHI_ONLYEMBEDDINGS.out.csv_gz,
        EMPATHI_INSTALL.out.models.collect()
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_*.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = (
        BAKTA_PROTEINS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'bakta' ], tsv_gz, 6, 'tsv.gz' ] }
        // .mix(DGRSCAN.out.txt_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'dgrscan' ], tsv_gz, 1, 'tsv.gz' ] })
        .mix(DEFENSEFINDER_RUN.out.genes_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'defensefinder' ], tsv_gz, 1, 'tsv.gz' ] })
        .mix(EMPATHI_EMPATHI.out.csv_gz.map { _meta, csv_gz -> csv_gz }.collect().map { csv_gz -> [ [ id:'empathi' ], csv_gz, 1, 'csv.gz' ] })
        .mix(PHAROKKA_PROTEINS.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'pharokka' ], tsv_gz, 1, 'tsv.gz' ] })
        .mix(PHOLD_COMPARE.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'phold' ], tsv_gz, 1, 'tsv.gz' ] })
    )
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/function"
    )
    

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_*.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = (
        PYRODIGALGV.out.fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:'pyrodigalgv' ], fna_gz, 'fna.gz' ] }
        .mix(FOLDSEEK_EASYSEARCH.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'foldseek' ], tsv_gz, 'tsv.gz' ] })
        .mix(INTERPROSCAN_INTERPROSCAN.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'interproscan' ], tsv_gz, 'tsv.gz' ] })
        .mix(CARD_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'card' ], tsv_gz, 'tsv.gz' ] })
        .mix(VFDB_DIAMOND.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'vfdb' ], tsv_gz, 'tsv.gz' ] })
    )
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/function"
    )

    emit:
    protein2hash_tsv_gz = UHVDB_PROTEINHASH.out.tsv_gz
    protein_faa_gz      = UHVDB_PROTEINHASH.out.faa_gz
    protein_fna_gz      = UHVDB_CATNOHEADER.out.combined.filter { meta, fna_gz -> meta.id == 'pyrodigalgv' } // (for instrain)
    // dgrscan_tsv_gz      = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'dgrscan' }
    bakta_tsv_gz        = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'bakta' }
    foldseek_tsv_gz     = UHVDB_CATNOHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'foldseek' }
    interproscan_tsv_gz = UHVDB_CATNOHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'interproscan' }
    card_tsv_gz         = UHVDB_CATNOHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'card' }
    vfdb_tsv_gz         = UHVDB_CATNOHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'vfdb' }
    defensefinder_tsv_gz= UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'defensefinder' }
    pharokka_tsv_gz     = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'pharokka' } // (for lifestyle subworkflow)
    phold_tsv_gz        = UHVDB_CATHEADER.out.combined.filter { meta, tsv_gz -> meta.id == 'phold' } // (for lifestyle subworkflow)
    empathi_csv_gz      = UHVDB_CATHEADER.out.combined.filter { meta, csv_gz -> meta.id == 'empathi' } // (for lifestyle subworkflow)

}

