/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
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
include { UHVDB_CATHEADER       } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER     } from '../../../modules/local/uhvdb/catnoheader'

workflow UPDATE {

    take:
    ch_virus_mq_plus_fna_gz     // [ [ meta ], mq_plus_virus.fna.gz ]
    ch_seqhasher_tsv_gz         // [ [ meta ], seqhasher.tsv.gz ]
    ch_hq_viruses_unique_fna_gz // [ [ meta ], hq_viruses_unique.fna.gz ]
    ch_hq_viruses_unique_tsv_gz // [ [ meta ], hq_viruses_unique.tsv.gz ]
    ch_hq_viruses_genomovars_fna_gz // [ [ meta ], hq_viruses_genomovars.fna.gz ]
    ch_hq_viruses_genomovars_tsv_gz // [ [ meta ], hq_viruses_genomovars.tsv.gz ]
    // ch_classify_rename_tsv_gz   // [ [ meta ], classify_rename.classify.tsv.gz ]

    main:

    if ( !file("${params.uhvdb_dir}/mq_plus_viruses.fna.gz").exists() ) {
        ch_uhvdb_mq_plus_virus_fna_gz = ch_virus_mq_plus_fna_gz
            .map { _meta, fna_gz -> [ [ id:'uhvdb_mq_plus_virus' ], fna_gz, 'fna.gz' ] }
    } else {
        ch_uhvdb_mq_plus_virus_fna_gz = channel.fromPath("${params.uhvdb_dir}/mq_plus_viruses.fna.gz")
            .mix(
                ch_virus_mq_plus_fna_gz.map { _meta, fna_gz -> fna_gz }
            )
            .collect()
            .map { fna_gz -> [ [ id:'mq_plus_viruses' ], fna_gz, 'fna.gz' ] }
    }

    //-------------------------------------------
    // MODULE: UHVDB_CATNOHEADER
    // inputs:
    // - [ [ meta ], [ uhvdb_mq_plus_virus.fna.gz new_mq_plus.fna.gz ] ]
    // - [ storeDir ]
    // outputs:
    // - [ [ meta ], uhvdb_mq_plus_virus.fna.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = ch_uhvdb_mq_plus_virus_fna_gz
        .mix(ch_hq_viruses_unique_fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:'hq_viruses_unique' ], fna_gz, 'fna.gz' ] })
        .mix(ch_hq_viruses_genomovars_fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:'hq_viruses_genomovars' ], fna_gz, 'fna.gz' ] })
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/uhvdb_${params.new_release_id}/"
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *.${suffix} ... ] ]
    // outputs:
    // - [ [ meta ], ${meta.id}.${suffix} ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = ch_seqhasher_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.map { tsv_gz -> [ [ id:'hq_viruses_seqhasher' ], tsv_gz, 1, 'tsv.gz' ] }
        .mix(ch_hq_viruses_unique_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.map { tsv_gz -> [ [ id:'hq_viruses_unique' ], tsv_gz, 1, 'tsv.gz' ] })
        .mix(ch_hq_viruses_genomovars_tsv_gz.map { _meta, tsv_gz -> tsv_gz }.map { tsv_gz -> [ [ id:'hq_viruses_genomovars' ], tsv_gz, 1, 'tsv.gz' ] })
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/uhvdb_${params.new_release_id}/"
    )

    // emit:
    
}

