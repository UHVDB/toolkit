include { rmEmptyFastAs; rmEmptyTsvs                          } from '../functions/main'
include { FASTP_DEACON_MVIRS_PROPAGATE_VCLUST                 } from '../../../modules/local/fastp_deacon_mvirs_propagate_vclust/main'
include { SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST          } from '../../../modules/local/sracha_fastp_deacon_mvirs_propagate_vclust/main'
include { UHVDB_ASSEMBLYACTIVITY                              } from '../../../modules/local/uhvdb/assemblyactivity/main'

workflow ASSEMBLYANALYZE {

    take:
    reads               // channel: [ val(meta), fastq ]
    sras                // channel: [ val(meta), acc ]
    deacon_idx          // channel: [ deacon_idx ]
    fastas              // channel: [ val(meta), fna ]
    confident_fna_gz    // channel: [ val(meta), fna_gz ]
    classify_tsv_gz     // channel: [ val(meta), tsv_gz ]
    species_reps_fna_gz // channel: [ species_reps_fna_gz ]
    sylphmpa            // channel: [ val(meta), sylphmpa ]
    uhvdb_metadata_tsv_gz // channel: [ uhvdb_metadata_tsv_gz ]

    main:

    // Local assemblies only (same rule as CLASSIFY when --run_assembly_analyze)
    ch_assemblies = rmEmptyFastAs(fastas)
        .filter { _meta, fasta -> !file(fasta).toUri().toString().startsWith('https://') }

    // Pair classify with optional confident FASTA first. Do not remainder-join
    // confident onto the reads/SRA channels: an empty reads channel would emit
    // unmatched confident items as [id, null, fna].
    ch_classify_confident = rmEmptyTsvs(classify_tsv_gz)
        .map { meta, tsv -> [ meta.id, tsv ] }
        .join(
            confident_fna_gz.map { meta, fna -> [ meta.id, fna ] },
            remainder: true
        )
        .filter { _id, tsv, _confident -> tsv }

    ch_reads_for_assemblyanalyze = reads
        .map { meta, fastq -> [ meta.id, meta, fastq ] }
        .combine(ch_assemblies.map { meta, fna -> [ meta.id, fna ] }, by: 0)
        .join(ch_classify_confident)
        .map { _id, meta, fastq, fna, classify, confident -> [ meta, fastq, fna, classify, confident ] }

    ch_sras_for_assemblyanalyze = sras
        .map { meta, acc -> [ meta.id, meta, acc ] }
        .combine(ch_assemblies.map { meta, fna -> [ meta.id, fna ] }, by: 0)
        .join(ch_classify_confident)
        .map { _id, meta, acc, fna, classify, confident -> [ meta, acc, fna, classify, confident ] }

    //
    // MODULE: Download, preprocess, and analyse SRA reads against sample assemblies
    //
    SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST(
        ch_sras_for_assemblyanalyze,
        deacon_idx,
        species_reps_fna_gz
    )

    //
    // MODULE: Preprocess and analyse local reads against sample assemblies
    //
    FASTP_DEACON_MVIRS_PROPAGATE_VCLUST(
        ch_reads_for_assemblyanalyze,
        deacon_idx,
        species_reps_fna_gz
    )

    ch_mvirs_for_assemblyactivity = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.mvirs_fasta_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.mvirs_fasta_gz)
        .map { meta, fasta -> [ meta.id, fasta ] }
    ch_propagate_for_assemblyactivity = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.propagate_tsv_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.propagate_tsv_gz)
        .map { meta, tsv -> [ meta.id, tsv ] }
    ch_gani_for_assemblyactivity = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.gani_tsv_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.gani_tsv_gz)
        .map { meta, tsv -> [ meta.id, tsv ] }

    ch_referenceactivity_for_assemblyactivity = sylphmpa
        .map { meta, profile -> [ meta.id, meta, profile ] }
        .join(ch_classify_confident.map { id, tsv, _confident -> [ id, tsv ] })
        .join(ch_mvirs_for_assemblyactivity)
        .join(ch_propagate_for_assemblyactivity)
        .join(ch_gani_for_assemblyactivity)
        .map { _id, meta, profile, classify, mvirs, propagate, gani ->
            [ meta, profile, classify, mvirs, propagate, gani ]
        }

    //
    // MODULE: Add assembly activity columns to REFERENCEACTIVITY sylphmpa via GANI RBHs
    //
    UHVDB_ASSEMBLYACTIVITY(
        ch_referenceactivity_for_assemblyactivity,
        uhvdb_metadata_tsv_gz
    )

    emit:
    mvirs_fasta_gz   = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.mvirs_fasta_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.mvirs_fasta_gz)
    propagate_tsv_gz = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.propagate_tsv_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.propagate_tsv_gz)
    ani_tsv_gz       = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.ani_tsv_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.ani_tsv_gz)
    gani_tsv_gz      = SRACHA_FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.gani_tsv_gz
        .mix(FASTP_DEACON_MVIRS_PROPAGATE_VCLUST.out.gani_tsv_gz)
    sylphmpa         = UHVDB_ASSEMBLYACTIVITY.out.sylphmpa
}
