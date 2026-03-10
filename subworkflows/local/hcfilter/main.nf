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
include { GENOMAD_DOWNLOADHALLMARKS } from '../../../modules/local/genomad/downloadhallmarks/main.nf'
include { GENOMAD_HMMSEARCH         } from '../../../modules/local/genomad/hmmsearch/main.nf'
include { SEQKIT_SPLIT2             } from '../../../modules/local/seqkit/split2'
include { SEQHASHER                 } from '../../../modules/local/seqhasher'
include { TRTRIMMER                 } from '../../../modules/local/trtrimmer'
include { UHVDB_CATHEADER           } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_RENAME              } from '../../../modules/local/uhvdb/rename'
include { UHVDB_CLASSIFYRENAME      } from '../../../modules/local/uhvdb/classifyrename'
include { UHVDB_UNIQUEHASH          } from '../../../modules/local/uhvdb/uniquehash'
include { UHVDB_UNCERTAIN           } from '../../../modules/local/uhvdb/uncertain'
include { VCLUST_ALL2ALL as UNIQUE_VCLUST } from '../../../modules/local/vclust/all2all'
include { VCLUST_ALL2ALL as GENOMOVAR_VCLUST } from '../../../modules/local/vclust/all2all'

workflow HCFILTER {

    take:
    fna_gz  // [ [ meta ], hq_virus.part_*.fna.gz ]
    tsv_gz  // [ [ meta ], uhvdb_classify.tsv.gz ]

    main:

    if ( !file("${params.uhvdb_dir}/hq_viruses_seqhasher.tsv.gz").exists() ) {
        ch_uhvdb_seqhasher_tsv_gz = channel.of([])
    } else {
        ch_uhvdb_seqhasher_tsv_gz = channel.fromPath("${params.uhvdb_dir}/hq_viruses_seqhasher.tsv.gz")
    }

    if ( !file("${params.uhvdb_dir}/hq_viruses_unique.fna.gz").exists() ) {
        ch_uhvdb_unique_fna_gz = channel.of([])
    } else {
        ch_uhvdb_unique_fna_gz = channel.fromPath("${params.uhvdb_dir}/hq_viruses_unique.fna.gz")
    }

    if ( !file("${params.uhvdb_dir}/hq_viruses_genomovars.fna.gz").exists() ) {
        ch_uhvdb_genomovar_fna_gz = channel.of([])
    } else {
        ch_uhvdb_genomovar_fna_gz = channel.fromPath("${params.uhvdb_dir}/hq_viruses_genomovars.fna.gz")
            .map { fna_gz -> [ fna_gz ] }
    }

    if ( !file("${params.uhvdb_dir}/hq_hc_viruses_genomovars.fna.gz").exists() ) {
        ch_uhvdb_genomovar_hc_fna_gz = channel.of([])
    } else {
        ch_uhvdb_genomovar_hc_fna_gz = channel.fromPath("${params.uhvdb_dir}/hq_hc_viruses_genomovars.fna.gz")
            .map { fna_gz -> [ fna_gz ] }
    }

    if ( !file("${params.uhvdb_dir}/hq_hc_viruses_metadata.tsv.gz").exists() ) {
        ch_uhvdb_metadata_tsv_gz = channel.of([])
    } else {
        ch_uhvdb_metadata_tsv_gz = channel.fromPath("${params.uhvdb_dir}/hq_hc_viruses_metadata.tsv.gz")
            .map { tsv_gz -> [ tsv_gz ] }
    }

    //-------------------------------------------
    // MODULE: GENOMAD_DOWNLOADHALLMARKS
    // outputs:
    // - [ [ meta ], "genomad_1_9_hallmarks.hmm" ]
    // steps:
    // - Download geNomad data (script)
    // - Identify hallmarks (script)
    // - Extract hallmarks (script)
    // - Combine hallmarks (script)
    // - Cleanup (script)
    //--------------------------------------------
    GENOMAD_DOWNLOADHALLMARKS()

    //-------------------------------------------
    // MODULE: TRTRIMMER
    // inputs:
    // - [ [ meta ], uhvdb_hqfilter.fna.gz ]
    // outputs:
    // - [ [ meta ], uhvdb_hqfilter.tr-trimmer.fna.gz ]
    // steps:
    // - Trim DTRs (script)
    // - Compress (script)
    //--------------------------------------------
    TRTRIMMER(
        fna_gz
    )

    //-------------------------------------------
    // MODULE: SEQHASHER
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - rename (boolean)
    // outputs:
    // - [ [ meta ], uhvdb_hqfilter.tr-trimmer.fna.gz ]
    // steps:
    // - Add prefix (script)
    // - Trim DTRs (script)
    // - Calculate sequence hashes (script)
    // - Compress output (script)
    // - Cleanup (script)
    //-------------------------------------------
    SEQHASHER(
        TRTRIMMER.out.fna_gz,
        false
    )

    //-------------------------------------------
    // MODULE: UHVDB_UNIQUEHASH
    // inputs:
    // - [ [ meta ], [ virus.seqhasher.part_*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], virus.unique.tsv.gz ]
    // - [ [ meta ], virus.unique.fna.gz ]
    // steps:
    // - Concatenate TSVs (script)
    // - Identify unique hashes (script)
    // - Write out tsv (script)
    // - Write out fasta (script)
    // - Cleanup (script)
    //-------------------------------------------
    ch_unique_input = SEQHASHER.out.tsv_gz
        .map { _meta, tsv_gz -> [ tsv_gz ] }
        .collect()
        .map { tsv_gzs -> [ [ id:'hq_virus' ], tsv_gzs ] }
    UHVDB_UNIQUEHASH(
        ch_unique_input,
        ch_uhvdb_seqhasher_tsv_gz,
        tsv_gz.map { _neta, tsv_gz -> tsv_gz },
        ch_uhvdb_metadata_tsv_gz,
        "${params.output_dir}/${params.new_release_id}_outputs/hcfilter/"
    )

    //-------------------------------------------
    // MODULE: UNIQUE_VCLUST
    // inputs:
    // - [ [ meta ], virus.unique.fna.gz ]
    // outputs:
    // - [ [ meta ], virus_derep.clusters.tsv.gz ]
    // - [ [ meta ], virus_derep.reps.fna.gz ]
    // steps:
    // - Run vClust (script)
    // - Extract reps (script)
    // - Compress (script)
    // - Cleanup (script)
    //-------------------------------------------
    UNIQUE_VCLUST(
        UHVDB_UNIQUEHASH.out.fna_gz.map { meta, fna_gz -> meta.id = 'hq_virus_unique'; return [ meta, fna_gz ] },
        ch_uhvdb_unique_fna_gz,
        1.0,     // min_ani
        1.0,     // min_af
        "${params.output_dir}/${params.new_release_id}_outputs/hcfilter/unique/vclust/"
    )

    //-------------------------------------------
    // MODULE: GENOMOVAR_VCLUST
    // inputs:
    // - [ [ meta ], virus_derep.reps.fna.gz ]
    // outputs:
    // - [ [ meta ], virus_genomovar.clusters.tsv.gz ]
    // - [ [ meta ], virus_genomovar.reps.fna.gz ]
    // steps:
    // - Run vClust (script)
    // - Extract reps (script)
    // - Compress (script)
    // - Cleanup (script)
    //-------------------------------------------
    GENOMOVAR_VCLUST(
        UNIQUE_VCLUST.out.new_fna_gz.map { meta, fna_gz -> meta.id = 'hq_viruses_genomovars'; return [ meta, fna_gz ] },
        ch_uhvdb_genomovar_fna_gz,
        0.995,     // min_ani
        1.0,      // min_af
        "${params.output_dir}/${params.new_release_id}_outputs/hcfilter/genomovars/vclust/"
    )

    //-------------------------------------------
    // MODULE: UHVDB_UNCERTAIN
    // inputs:
    // - [ [ meta ], virus_genomovar.reps.fna.gz ]
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // outputs:
    // - [ [ meta ], virus.uncertain.fna.gz ]
    // steps:
    // - Identify uncertain viruses (script)
    // - Extract uncertain viruses (script)
    // - Cleanup (script)
    //-------------------------------------------
    UHVDB_UNCERTAIN(
        GENOMOVAR_VCLUST.out.new_fna_gz.combine(tsv_gz.map { _meta, tsv_gz -> return [ tsv_gz ] }),
    )

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.uncertain.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.uncertain.part_*.fna.gz ... ] ]
    // steps:
    // - Split fasta into chunks (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        UHVDB_UNCERTAIN.out.uncertain_fna_gz,
        params.hmmsearch_split_size
    )
    ch_split_viruses_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fna", "") ], fna_gz ]
        }

    //-------------------------------------------
    // MODULE: GENOMAD_HMMSEARCH
    // inputs:
    // - [ [ meta ], virus.unique.part_*.fna.gz ]
    // - [ "genomad_1_9_hallmarks.hmm" ]
    // - [ "genomad_metadata_v1.9.tsv.gz" ]
    // outputs:
    // - [ [ meta ], virus.uncertain2confident.part_*.fna.gz ]
    // - [ [ meta ], virus.hmmsearch.part_*.tsv.gz ]
    // steps:
    // - Predict genes (script)
    // - Run hmmsearch (script)
    // - Identify confident viruses (script)
    // - Extract confident viruses (script)
    // - Cleanup (script)
    //-------------------------------------------
    GENOMAD_HMMSEARCH(
        ch_split_viruses_fna_gz,
        GENOMAD_DOWNLOADHALLMARKS.out.hmm,
        GENOMAD_DOWNLOADHALLMARKS.out.tsv_gz
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], [ virus.hmmsearch.part_*.tsv.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_catheader_input = GENOMAD_HMMSEARCH.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'hcfilter' ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}_outputs/hcfilter"
    )


    //-------------------------------------------
    // MODULE: UHVDB_RENAME
    // inputs:
    // - [ [ meta ], [ virus.confident.fna.gz, virus.uncertain2confident.part_*.fna.gz ... ] ]
    // outputs:
    // - [ [ meta ], uhvdb_hc_hq_viruses.fna.gz ]
    // - [ [ meta ], uhvdb_hc_hq_virus.id_mapping.tsv.gz ]
    // steps:
    // - Combine files (script)
    //--------------------------------------------
    ch_rename_input = GENOMAD_HMMSEARCH.out.fna_gz
        .mix( UHVDB_UNCERTAIN.out.certain_fna_gz )
        .map { _meta, fna_gz -> fna_gz }
        .collect()
        .map { fna_gz -> [ [ id:'hq_hc_virus_genomovar' ], fna_gz ] }
    UHVDB_RENAME(
        ch_rename_input,
        ch_uhvdb_genomovar_hc_fna_gz,
        "${params.output_dir}/${params.new_release_id}_outputs/rename"
    )

    //-------------------------------------------
    // MODULE: UHVDB_CLASSIFYRENAME
    // inputs:
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // - [ [ meta ], uhvdb_hc_hq_virus.id_mapping.tsv.gz ]
    // outputs:
    // - [ [ meta ], uhvdb_hc_hq_virus_classify.tsv.gz ]
    // steps:
    // - Replace seq_name in classify.tsv.gz (script)
    // - Compress (script)
    //--------------------------------------------
    UHVDB_CLASSIFYRENAME(
        tsv_gz.map { _meta, tsv_gz -> [ [ id: 'classify_rename' ], tsv_gz ] },
        UHVDB_RENAME.out.tsv_gz.map { _meta, tsv_gz -> return tsv_gz },
        "${params.output_dir}/${params.new_release_id}_outputs/rename"
    )

    emit:
    seqhasher_tsv_gz            = UHVDB_UNIQUEHASH.out.tsv_gz
    hq_viruses_unique_fna_gz    = UNIQUE_VCLUST.out.all_fna_gz
    hq_viruses_unique_tsv_gz    = UNIQUE_VCLUST.out.tsv_gz
    hq_viruses_genomovars_fna_gz = GENOMOVAR_VCLUST.out.all_fna_gz
    hq_viruses_genomovars_tsv_gz = GENOMOVAR_VCLUST.out.tsv_gz
    uncertain_hallmark_tsv_gz    = UHVDB_CATHEADER.out.combined
    new_fna_gz  = UHVDB_RENAME.out.new_fna_gz
    all_fna_gz  = UHVDB_RENAME.out.all_fna_gz
    tsv_gz      = UHVDB_CATHEADER.out.combined
    classify_tsv_gz  = UHVDB_CLASSIFYRENAME.out.tsv_gz
}

