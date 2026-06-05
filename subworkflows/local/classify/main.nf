include { rmEmptyFastAs; rmEmptyTsvs; add_split; extractDigitBeforeExtension } from '../functions/main'
include { CHECKV_DOWNLOADDATABASE   } from '../../../modules/nf-core/checkv/downloaddatabase/main'
include { GENOMAD_DOWNLOAD          } from '../../../modules/nf-core/genomad/download/main'
include { VIRALVERIFY_DOWNLOAD      } from '../../../modules/local/viralverify/download/main'
include { SEQKIT_SEQ_REPLACE_SPLIT2 } from '../../../modules/local/seqkit/seq_replace_split2/main'
include { GENOMAD_CSVTK_SEQKIT      } from '../../../modules/local/genomad_csvtk_seqkit/main'
include { ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT } from '../../../modules/local/aria2c_seqkit_genomad_csvtk_seqkit/main'
include { SEQKIT_GENOMAD_CSVTK_SEQKIT } from '../../../modules/local/seqkit_genomad_csvtk_seqkit/main'
include { CHECKV_SEQKIT_CSVTK_SEQKIT } from '../../../modules/local/checkv_csvtk_seqkit/main'
include { SEQKIT_REPLACE as SEQKIT_REPLACE_PROVIRUS } from '../../../modules/nf-core/seqkit/replace/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_CHECKV } from '../../../modules/nf-core/find/concatenate/main'
include { CSVTK_FILTER2             } from '../../../modules/local/csvtk/filter2/main'
include { SEQKIT_GREP               } from '../../../modules/nf-core/seqkit/grep/main'
include { VIRALVERIFY_VIRALVERIFY       } from '../../../modules/local/viralverify/viralverify/main'
include { UHVDB_CLASSIFY                } from '../../../modules/local/uhvdb/classify/main'
include { FIND_CONCATENATEHEADERS          } from '../../../modules/local/find/concatenateheaders/main'

workflow CLASSIFY {

    take:
    fastas              // channel: [ val(meta), fna ]
    dtr_sequences_file  // string, DTR sequences file
    checkv_db           // channel: [ checkv_db ]

    main:
    // Create channels for combining geNomad's outputs
    ch_genomad_virus_fna_gz = channel.empty()
    ch_genomad_virus_summary_tsv_gz = channel.empty()
    ch_genomad_virus_genes_tsv_gz = channel.empty()

    //
    // MODULE: Download genomad's database
    //
    GENOMAD_DOWNLOAD()
    ch_genomad_db = GENOMAD_DOWNLOAD.out.genomad_db.collect()

    //
    // MODULE: Download viralverify's database
    //
    VIRALVERIFY_DOWNLOAD()
    ch_viralverify_db = VIRALVERIFY_DOWNLOAD.out.viralverify_db.collect()

    // Split fasta files based on source_type
    fastas = fastas.branch { meta, _fasta ->
        assembly: meta.source_type == 'Assembly'
        database: meta.source_type == 'Database'
    }

    //
    // MODULE: Length filter, add sample_id as prefix, and split database fasta files
    //
    SEQKIT_SEQ_REPLACE_SPLIT2(
        fastas.database
    )
    ch_split_database_fastas = SEQKIT_SEQ_REPLACE_SPLIT2.out.fastx
        .transpose()
        .map{ meta, fastx ->
            [ add_split(meta, fastx.getName()), [ fastx ] ] }

    //
    // MODULE: Run geNomad end-to-end on database fasta files
    //
    GENOMAD_CSVTK_SEQKIT(
        ch_split_database_fastas,
        ch_genomad_db
    )
    ch_genomad_virus_fna_gz = ch_genomad_virus_fna_gz.mix(GENOMAD_CSVTK_SEQKIT.out.fna_gz)
    ch_genomad_virus_summary_tsv_gz = ch_genomad_virus_summary_tsv_gz.mix(GENOMAD_CSVTK_SEQKIT.out.summary_tsv_gz)
    ch_genomad_virus_genes_tsv_gz = ch_genomad_virus_genes_tsv_gz.mix(GENOMAD_CSVTK_SEQKIT.out.genes_tsv_gz)

    // Identify remote fasta files and split them into chunks of size params.url_split_size
    ch_remote_assemblies = fastas.assembly
        .filter { _meta, fasta -> file(fasta).toUri().toString().startsWith('https://') }
        .map { meta, fasta ->
            def source_db = meta.source_db ?: 'NA'
            def body_site = meta.body_site ?: 'NA'
            return [ [ body_site: body_site, source_db: source_db ], [ meta.id, fasta ] ]
        }
        .groupTuple() // Combine URLs by source_db, source_type, and body_site
        .map { meta, id_fasta_list ->
            id_fasta_list
                .collate(params.url_split_size) // Split fasta files into chunks of size params.url_split_size
                .withIndex() // Add index to each chunk
                .collect { batch, idx ->
                    def batch_meta = meta + [ id: "${meta.source_db}_${meta.body_site}_batch_${idx}" ]
                    [ batch_meta, batch ] // Create a new meta with the source_db and batch index
                }
        }
        .flatMap { batches -> batches }   // one [meta, batch] per emission

    //
    // MODULE: Download, length filter, and run genomad end-to-end on remote fasta files
    //
    ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT(
        ch_remote_assemblies,
        ch_genomad_db
    )

    ch_genomad_virus_fna_gz = ch_genomad_virus_fna_gz.mix(ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT.out.fna_gz)
    ch_genomad_virus_summary_tsv_gz = ch_genomad_virus_summary_tsv_gz.mix(ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT.out.summary_tsv_gz)
    ch_genomad_virus_genes_tsv_gz = ch_genomad_virus_genes_tsv_gz.mix(ARIA2C_SEQKIT_GENOMAD_CSVTK_SEQKIT.out.genes_tsv_gz)

    // Identify local fasta files and split them into chunks of size params.url_split_size
    ch_local_assemblies = rmEmptyFastAs(fastas.assembly)
        .filter { _meta, fasta -> !file(fasta).toUri().toString().startsWith('https://') }
        .map { meta, fasta ->
            def source_db = meta.source_db ?: 'NA'
            def body_site = meta.body_site ?: 'NA'
            return [ [ body_site: body_site, source_db: source_db ], [ meta.id, fasta ] ]
        }
        .groupTuple() // Combine URLs by source_db, source_type, and body_site
        .map { meta, id_fasta_list ->
            id_fasta_list
                .collate(params.url_split_size) // Split fasta files into chunks of size params.url_split_size
                .withIndex() // Add index to each chunk
                .collect { batch, idx ->
                    def batch_meta = meta + [ id: "${meta.source_db}_${meta.body_site}_batch_${idx}" ]
                    [ batch_meta, batch ] // Create a new meta with the source_db and batch index
                }
        }
        .flatMap { batches -> batches }   // one [meta, batch] per emission
        .map { meta, id_fasta -> [ meta, id_fasta, id_fasta.collect { _id, fasta -> fasta } ] }

    //
    // MODULE: Length filter and run genomad end-to-end on local fasta files
    //
    SEQKIT_GENOMAD_CSVTK_SEQKIT(
        ch_local_assemblies,
        ch_genomad_db
    )

    ch_genomad_virus_fna_gz = ch_genomad_virus_fna_gz.mix(SEQKIT_GENOMAD_CSVTK_SEQKIT.out.fna_gz)
    ch_genomad_virus_summary_tsv_gz = ch_genomad_virus_summary_tsv_gz.mix(SEQKIT_GENOMAD_CSVTK_SEQKIT.out.summary_tsv_gz)
    ch_genomad_virus_genes_tsv_gz = ch_genomad_virus_genes_tsv_gz.mix(SEQKIT_GENOMAD_CSVTK_SEQKIT.out.genes_tsv_gz)

    //
    // MODULE: Run CheckV end-to-end
    //
    CHECKV_SEQKIT_CSVTK_SEQKIT(
        rmEmptyFastAs(ch_genomad_virus_fna_gz),
        checkv_db
    )

    //
    // MODULE: Run ViralVerify
    //
    VIRALVERIFY_VIRALVERIFY(
        rmEmptyFastAs(CHECKV_SEQKIT_CSVTK_SEQKIT.out.fna_gz),
        ch_viralverify_db
    )

    // Combine geNomad, CheckV, and viralverify outputs
    ch_uhvdb_classify_input = rmEmptyFastAs(CHECKV_SEQKIT_CSVTK_SEQKIT.out.fna_gz)
        .join(ch_genomad_virus_summary_tsv_gz)
        .join(ch_genomad_virus_genes_tsv_gz)
        .join(CHECKV_SEQKIT_CSVTK_SEQKIT.out.summary_tsv_gz)
        .join(rmEmptyTsvs(VIRALVERIFY_VIRALVERIFY.out.csv_gz))

    //
    // MODULE: Classify viruses by combining results from geNomad, CheckV, and ViralVerify
    //
    UHVDB_CLASSIFY(
        ch_uhvdb_classify_input,
        dtr_sequences_file
    )

    //
    // MODULE: Combine classify tsv file
    //
    FIND_CONCATENATEHEADERS(
        UHVDB_CLASSIFY.out.tsv_gz.map { _meta, tsv_gz -> [ tsv_gz ] }.collect().map { tsv_gzs -> [ [ id:'combined_classify' ], tsv_gzs ] },
        1
    )

    emit:
    checkv_db       = checkv_db
    virus_fna_gz    = UHVDB_CLASSIFY.out.fna_gz
    complete_fna_gz = UHVDB_CLASSIFY.out.complete_fna_gz
    tsv_gz          = UHVDB_CLASSIFY.out.tsv_gz
    combined_tsv_gz = FIND_CONCATENATEHEADERS.out.file_out
}
