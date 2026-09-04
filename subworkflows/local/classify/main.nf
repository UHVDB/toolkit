include { rmEmptyFastAs; rmEmptyTsvs; add_split             } from '../functions/main'
include { GENOMAD_DOWNLOAD                                  } from '../../../modules/local/genomad/download/main'
include { VIRALVERIFY_DOWNLOAD                              } from '../../../modules/local/viralverify/download/main'
include { SEQKIT_SEQ_REPLACE_SPLIT2                         } from '../../../modules/local/seqkit_seq_replace_split2/main'
include { GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY               } from '../../../modules/local/genomad_checkv_viralverify_classify/main'
include { ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY } from '../../../modules/local/aria2c_seqkit_genomad_checkv_viralverify_classify/main'
include { SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY        } from '../../../modules/local/seqkit_genomad_checkv_viralverify_classify/main'
include { FIND_CONCATENATEHEADERS                           } from '../../../modules/local/find/concatenateheaders/main'

workflow CLASSIFY {

    take:
    fastas              // channel: [ val(meta), fna ]
    dtr_sequences       // channel: [ val(meta), txt ]
    checkv_db           // channel: [ checkv_db ]
    hmm                 // channel: [ genomad_1_9_hallmarks.hmm ]
    hmm_tsv_gz          // channel: [ genomad_metadata_v1.9.tsv.gz ]

    main:
    ch_confident_fna_gz = channel.empty()
    ch_complete_fna_gz  = channel.empty()
    ch_classify_tsv_gz  = channel.empty()
    ch_hcfilter_tsv_gz  = channel.empty()

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
    // MODULE: Length filter, add sample_id as prefix, and split DATABASE fasta files by params.database_split_size
    //
    SEQKIT_SEQ_REPLACE_SPLIT2(
        fastas.database
    )
    ch_split_database_fastas = SEQKIT_SEQ_REPLACE_SPLIT2.out.fastx
        .transpose()
        .map{ meta, fastx ->
            [ add_split(meta, fastx.getName()), [ fastx ] ] }

    //
    // MODULE: Run geNomad, CheckV, ViralVerify, and UHVDB classify on DATABASE fasta files
    //
    GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY(
        ch_split_database_fastas,
        ch_genomad_db,
        checkv_db,
        ch_viralverify_db,
        dtr_sequences,
        hmm,
        hmm_tsv_gz
    )
    ch_confident_fna_gz = ch_confident_fna_gz.mix(GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.confident_fna_gz)
    ch_complete_fna_gz  = ch_complete_fna_gz.mix(GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.complete_fna_gz)
    ch_classify_tsv_gz  = ch_classify_tsv_gz.mix(GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.classify_tsv_gz)
    ch_hcfilter_tsv_gz  = ch_hcfilter_tsv_gz.mix(GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.hcfilter_tsv_gz)

    // Identify remote ASSEMBLY fasta files and split them into chunks of size params.assembly_split_size
    if (params.run_assembly_analyze) {
        ch_remote_assemblies = fastas.assembly
            .filter { _meta, fasta -> file(fasta).toUri().toString().startsWith('https://') }
            .map { meta, fasta ->
                [ meta, [ [ meta.id, fasta ] ], fasta ]
            }
    } else {
        ch_remote_assemblies = fastas.assembly
            .filter { _meta, fasta -> file(fasta).toUri().toString().startsWith('https://') }
            .map { meta, fasta ->
                def source_db = meta.source_db ?: 'NO_DB'
                def body_site = meta.body_site ?: 'Other'
                return [ [ body_site: body_site, source_db: source_db ], [ meta.id, fasta ] ]
            }
            .groupTuple() // Combine URLs by source_db, source_type, and body_site
            .map { meta, id_fasta_list ->
                id_fasta_list
                    .collate(params.assembly_split_size) // Split fasta files into chunks of size params.assembly_split_size
                    .withIndex() // Add index to each chunk
                    .collect { batch, idx ->
                        def batch_meta = meta + [ id: "remote_${meta.source_db}_${meta.body_site}_batch_${idx}" ]
                        [ batch_meta, batch ] // Create a new meta with the source_db and batch index
                    }
            }
            .flatMap { batches -> batches }   // one [meta, batch] per emission
    }

    //
    // MODULE: Download, length filter, and classify remote fasta files
    //
    ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY(
        ch_remote_assemblies,
        ch_genomad_db,
        checkv_db,
        ch_viralverify_db,
        dtr_sequences,
        hmm,
        hmm_tsv_gz
    )
    ch_confident_fna_gz = ch_confident_fna_gz.mix(ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.confident_fna_gz)
    ch_complete_fna_gz  = ch_complete_fna_gz.mix(ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.complete_fna_gz)
    ch_classify_tsv_gz  = ch_classify_tsv_gz.mix(ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.classify_tsv_gz)
    ch_hcfilter_tsv_gz  = ch_hcfilter_tsv_gz.mix(ARIA2C_SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.hcfilter_tsv_gz)

    // Identify local ASSEMBLY fasta files (one classify job per sample)
    if (params.run_assembly_analyze) {
        ch_local_assemblies = rmEmptyFastAs(fastas.assembly)
            .filter { _meta, fasta -> !file(fasta).toUri().toString().startsWith('https://') }
            .map { meta, fasta ->
                [ meta, [ [ meta.id, fasta ] ], fasta ]
            }
    } else {
        ch_local_assemblies = rmEmptyFastAs(fastas.assembly)
            .filter { _meta, fasta -> !file(fasta).toUri().toString().startsWith('https://') }
            .map { meta, fasta ->
                def source_db = meta.source_db ?: 'NO_DB'
                def body_site = meta.body_site ?: 'Other'
                return [ [ body_site: body_site, source_db: source_db ], [ meta.id, fasta ] ]
            }
            .groupTuple() // Combine URLs by source_db, source_type, and body_site
            .map { meta, id_fasta_list ->
                id_fasta_list
                    .collate(params.assembly_split_size)
                    .withIndex() // Add index to each chunk
                    .collect { batch, idx ->
                        def batch_meta = meta + [ id: "local_${meta.source_db}_${meta.body_site}_batch_${idx}" ]
                        [ batch_meta, batch ] // Create a new meta with the source_db and batch index
                    }
            }
            .flatMap { batches -> batches }   // one [meta, batch] per emission
            .map { meta, id_fasta -> [ meta, id_fasta, id_fasta.collect { _id, fasta -> fasta } ] }
    }

    //
    // MODULE: Length filter and classify local fasta files
    //
    SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY(
        ch_local_assemblies,
        ch_genomad_db,
        checkv_db,
        ch_viralverify_db,
        dtr_sequences,
        hmm,
        hmm_tsv_gz
    )
    ch_confident_fna_gz = ch_confident_fna_gz.mix(SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.confident_fna_gz)
    ch_complete_fna_gz  = ch_complete_fna_gz.mix(SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.complete_fna_gz)
    ch_classify_tsv_gz  = ch_classify_tsv_gz.mix(SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.classify_tsv_gz)
    ch_hcfilter_tsv_gz  = ch_hcfilter_tsv_gz.mix(SEQKIT_GENOMAD_CHECKV_VIRALVERIFY_CLASSIFY.out.hcfilter_tsv_gz)

    // Remove empty fasta files and tsv files
    ch_confident_fna_gz = rmEmptyFastAs(ch_confident_fna_gz)
    ch_complete_fna_gz  = rmEmptyFastAs(ch_complete_fna_gz)
    ch_classify_tsv_gz  = rmEmptyTsvs(ch_classify_tsv_gz)
    ch_hcfilter_tsv_gz  = rmEmptyTsvs(ch_hcfilter_tsv_gz)

    //
    // MODULE: Combine classify tsv file
    //
    FIND_CONCATENATEHEADERS(
        ch_classify_tsv_gz.map { _meta, tsv_gz -> [ tsv_gz ] }.collect().map { tsv_gzs -> [ [ id:'combined_classify' ], tsv_gzs ] }
            .mix(ch_hcfilter_tsv_gz.map { _meta, tsv_gz -> [ tsv_gz ] }.collect().map { tsv_gzs -> [ [ id:'combined_hcfilter' ], tsv_gzs ] }),
        1
    )

    emit:
    confident_fna_gz = ch_confident_fna_gz
    complete_fna_gz  = ch_complete_fna_gz
    classify_tsv_gz  = ch_classify_tsv_gz
    hcfilter_tsv_gz  = ch_hcfilter_tsv_gz
    combined_tsv_gz  = FIND_CONCATENATEHEADERS.out.file_out
}
