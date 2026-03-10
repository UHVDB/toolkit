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
include { CHECKV_ENDTOEND               } from '../../../modules/local/checkv/endtoend'
include { ENA_GENOMAD                   } from '../../../modules/local/ena/genomad'
include { GENOMAD_ENDTOEND              } from '../../../modules/local/genomad/endtoend'
include { LOCAL_GENOMAD                 } from '../../../modules/local/local/genomad'
include { LOGAN_GENOMAD as ATB_GENOMAD  } from '../../../modules/local/logan/genomad'
include { LOGAN_GENOMAD                 } from '../../../modules/local/logan/genomad'
include { NCBI_GENOMAD                  } from '../../../modules/local/ncbi/genomad'
include { SEQKIT_SEQSPLIT2              } from '../../../modules/local/seqkit/seqsplit2'
include { SPIRE_GENOMAD                 } from '../../../modules/local/spire/genomad'
include { UHVDB_VIRUSFILTER             } from '../../../modules/local/uhvdb/virusfilter'
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_CATNOHEADER             } from '../../../modules/local/uhvdb/catnoheader'
include { VIRALVERIFY_DOWNLOAD          } from '../../../modules/local/viralverify/download'
include { VIRALVERIFY_VIRALVERIFY       } from '../../../modules/local/viralverify/viralverify'


//
// WORFKLOW: Classify viruses in input fasta files
//
workflow CLASSIFY {

    take:
    fna_gz      // channel: [ [ meta ], fna.gz ]
    genomad_db  // channel: [ genomad_db ]
    checkv_db   // channel: [ checkv_db ]

    main:

    if ( file("${params.dtr_sequences_file}").exists() ) {
        ch_dtr_sequences = channel.fromPath("${params.dtr_sequences_file}")
    } else {
        ch_dtr_sequences = channel.of([]) 
    }

    //-------------------------------------------
    // MODULE: VIRALVERIFY_DOWNLOAD
    // outputs:
    // - [ [ meta ], "viralverify_db.hmm" ]
    // steps:
    // - Download database (script)
    // - Decompress (script)
    //--------------------------------------------
    VIRALVERIFY_DOWNLOAD()


    // Initialize output channels
    def ch_virus_summaries_tsv_gz = channel.empty()
    def ch_genomad_genes_tsv_gz = channel.empty()
    def ch_virus_fna_gz = channel.empty()

    //-------------------------------------------
    // MODULE: ATB_GENOMAD
    // inputs:
    // - [ [ meta ], [ atb_url.fna.gz ... ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Create arrays (script)
    // - Download assemblies (script)
    // - Remove short contigs (script)
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_atb_assembly_batches = fna_gz.filter { meta, _fasta -> meta.source_db == 'ATB' }
        .map { meta, fasta -> [ meta.id, fasta ] }
        .collate(params.url_split_size * 10)
        .toList()
        .flatMap{ id_fasta -> id_fasta.withIndex() }
        .map { id_fasta, index ->
            [ [ id: 'atb_batch_' + index, source_db: 'ATB' ], id_fasta ]
        }
    ATB_GENOMAD(
        ch_atb_assembly_batches,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(ATB_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(ATB_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(ATB_GENOMAD.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: ENA_GENOMAD
    // inputs:
    // - [ [ meta ], [ ena_url.fna.gz ... ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Create arrays (script)
    // - Download assemblies (script)
    // - Remove short contigs (script)
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_ena_urls = fna_gz.filter { meta, _fasta -> meta.source_db == 'ENA' }
        .map { meta, fasta -> [ meta.id, fasta ] }
        .collate(params.url_split_size)
        .toList()
        .flatMap{ id_fasta -> id_fasta.withIndex() }
        .map { id_fasta, index ->
            [ [ id: 'ena_batch_' + index, source_db: 'ENA' ], id_fasta ]
        }
    ENA_GENOMAD(
        ch_ena_urls,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(ENA_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(ENA_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(ENA_GENOMAD.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: NCBI_GENOMAD
    // inputs:
    // - [ [ meta ], [ ncbi_url.fna.gz ... ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Create arrays (script)
    // - Download assemblies (script)
    // - Remove short contigs (script)
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_ncbi_virus_urls = fna_gz.filter { meta, _fasta -> meta.source_db == 'NCBI_VIRUS' }
        .map { meta, fasta -> [ meta.id, fasta ] }
        .collate(params.url_split_size * 10)
        .toList()
        .flatMap{ id_fasta -> id_fasta.withIndex() }
        .map { id_fasta, index ->
            [ [ id: 'ncbi_virus_batch_' + index, source_db: 'NCBI' ], id_fasta ]
        }
    NCBI_GENOMAD(
        ch_ncbi_virus_urls,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(NCBI_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(NCBI_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(NCBI_GENOMAD.out.genes_tsv_gz)


    //-------------------------------------------
    // MODULE: LOCAL_SEQKIT_SPLIT2
    // inputs:
    // - [ [ meta ], [ local.fna.gz ... ] ]
    // outputs:
    // - [ [ meta ], [ *.fna.gz ... ]
    // steps:
    // - Remove short contigs (script)
    // - Split contigs (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_local_fastas = fna_gz
        .filter { meta, _fasta ->
            (
                meta.source_db != "ENA" &&
                meta.source_db != "NCBI_VIRUS" &&
                meta.source_db != "LOGAN" &&
                meta.source_db != "SPIRE" &&
                meta.source_db != "ATB" &&
                meta.source_db
            )
        }
        .map { meta, fasta ->
            meta.id = meta.source_db + "_" + meta.id
            [ meta, fasta ]
        }
    SEQKIT_SEQSPLIT2(
        ch_local_fastas,
        params.genomad_split_size
    )

    ch_split_fastas = SEQKIT_SEQSPLIT2.out.fastas_gz
        .filter { meta, files -> files.size() > 0 }
        .map { _meta, file -> file }
        .flatten()
        .map { file ->
            [ [ id: file.getBaseName().replace(".fasta", "") ], file ]
        }

    //-------------------------------------------
    // MODULE: LOCAL_GENOMAD
    // inputs:
    // - [ [ meta ], [ local.fna.gz ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    LOCAL_GENOMAD(
        ch_split_fastas,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(LOCAL_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(LOCAL_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(LOCAL_GENOMAD.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: LOGAN_GENOMAD
    // inputs:
    // - [ [ meta ], [ logan_url.fna.gz ... ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Create arrays (script)
    // - Download assemblies (script)
    // - Remove short contigs (script)
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_logan_assembly_batches = fna_gz.filter { meta, _fasta -> meta.source_db == 'LOGAN' }
        .map { meta, fasta -> [ meta.id, fasta ] }
        .collate(params.url_split_size * 5)
        .toList()
        .flatMap{ id_fasta -> id_fasta.withIndex() }
        .map { id_fasta, index ->
            [ [ id: 'logan_batch_' + index, source_db: 'LOGAN' ], id_fasta ]
        }
    
    LOGAN_GENOMAD(
        ch_logan_assembly_batches,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(LOGAN_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(LOGAN_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(LOGAN_GENOMAD.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: SPIRE_GENOMAD
    // inputs:
    // - [ [ meta ], [ spire_url.fna.gz ... ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Create arrays (script)
    // - Download assemblies (script)
    // - Remove short contigs (script)
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_spire_urls = fna_gz.filter { meta, _fasta -> meta.source_db == 'SPIRE' }
        .map { meta, fasta -> [ meta.id, fasta ] }
        .collate(params.url_split_size)
        .toList()
        .flatMap{ id_fasta -> id_fasta.withIndex() }
        .map { id_fasta, index ->
            [ [ id: 'spire_batch_' + index, source_db: 'SPIRE' ], id_fasta ]
        }
    SPIRE_GENOMAD(
        ch_spire_urls,
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(SPIRE_GENOMAD.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(SPIRE_GENOMAD.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(SPIRE_GENOMAD.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: GENOMAD_ENDTOEND
    // inputs:
    // - [ [ meta ], [ local.fna.gz ] ]
    // - [ genomad_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Run geNomad (script)
    // - Save virus outputs (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    def ch_no_db_fastas = fna_gz
        .filter { meta, _fasta ->
            (
                !meta.source_db
            )
        }
    GENOMAD_ENDTOEND(
        rmEmptyFastAs(ch_no_db_fastas),
        genomad_db
    )
    ch_virus_summaries_tsv_gz   = ch_virus_summaries_tsv_gz.mix(GENOMAD_ENDTOEND.out.summary_tsv_gz)
    ch_virus_fna_gz             = ch_virus_fna_gz.mix(GENOMAD_ENDTOEND.out.fna_gz)
    ch_genomad_genes_tsv_gz     = ch_genomad_genes_tsv_gz.mix(GENOMAD_ENDTOEND.out.genes_tsv_gz)

    //-------------------------------------------
    // MODULE: CHECKV_ENDTOEND
    // inputs:
    // - [ [ meta ], [ virus.fna.gz ] ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Run CheckV (script)
    // - Save outputs (script)
    // - Fix provirus headers (script)
    // - Remove LQ (script)
    // - Cleanup (script)
    //--------------------------------------------
    CHECKV_ENDTOEND(
        rmEmptyFastAs(ch_virus_fna_gz),
        checkv_db
    )

    //-------------------------------------------
    // MODULE: VIRALVERIFY
    // inputs:
    // - [ [ meta ], [ virus.fna.gz ] ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Uncompress (script)
    // - Run viralVerify (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    VIRALVERIFY_VIRALVERIFY(
        rmEmptyFastAs(CHECKV_ENDTOEND.out.virus_fna_gz),
        VIRALVERIFY_DOWNLOAD.out.viralverify_db
    )

    //-------------------------------------------
    // MODULE: UHVDB_VIRUSFILTER
    // inputs:
    // - [ [ meta ], [ virus.fna.gz ] ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // - [ [ meta ], virus_genes.tsv.gz ]
    // steps:
    // - Uncompress (script)
    // - Run viralVerify (script)
    // - Compress (script)
    // - Cleanup (script)
    //--------------------------------------------
    // prepare combined channel for filtering
    ch_virus_filter_input = rmEmptyFastAs(CHECKV_ENDTOEND.out.virus_fna_gz)
        .combine(ch_virus_summaries_tsv_gz, by:0)
        .combine(ch_genomad_genes_tsv_gz, by:0)
        .combine(CHECKV_ENDTOEND.out.quality_summary_tsv_gz, by:0)
        .combine(VIRALVERIFY_VIRALVERIFY.out.csv_gz, by:0)

    UHVDB_VIRUSFILTER(
        ch_virus_filter_input,
        ch_dtr_sequences.first()
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ *_uhvdb_virusfilter.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = UHVDB_VIRUSFILTER.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:"new_classify" ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}_outputs/classify/"
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATNOHEADER
    // inputs:
    // - [ [ meta ], [ *_uhvdb_virusfilter.fna.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.fna.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catnoheader_input = UHVDB_VIRUSFILTER.out.fna_gz.map { _meta, fna_gz -> fna_gz }.collect().map { fna_gz -> [ [ id:"new_mq_plus_viruses" ], fna_gz, 'fna.gz' ] }
    UHVDB_CATNOHEADER(
        ch_catnoheader_input,
        "${params.output_dir}/${params.new_release_id}_outputs/classify/"
    )

    emit:
    classify_tsv_gz         = UHVDB_CATHEADER.out.combined
    mq_plus_viruses_fna_gz  = UHVDB_CATNOHEADER.out.combined
}

