include { SEQKIT_SPLIT2 } from '../../../modules/local/seqkit/split2/main'
include { rmEmptyFastAs; add_split } from '../functions/main'
include { PYRODIGALGV } from '../../../modules/local/pyrodigalgv/main'
include { FIND_CONCATENATE } from '../../../modules/nf-core/find/concatenate/main'
include { DIAMOND_MAKEDB } from '../../../modules/nf-core/diamond/makedb/main'
include { DIAMOND_BLASTP as DIAMOND_BLASTP_V_NEW } from '../../../modules/nf-core/diamond/blastp/main.nf'
include { DIAMOND_BLASTP as DIAMOND_BLASTP_V_OLD } from '../../../modules/nf-core/diamond/blastp/main.nf'

workflow AAICLUSTER {

    take:
    new_species_reps_fna_gz
    old_species_reps_fna_gz

    main:

    //
    // MODULE: Split new + old genomovar reps into chunks
    //
    SEQKIT_SPLIT2(
        rmEmptyFastAs(new_species_reps_fna_gz.mix(old_species_reps_fna_gz))
    )
    ch_split_species_reps_fna_gz = SEQKIT_SPLIT2.out.fastx
        .transpose()
        .map{ meta, fastx ->
            [ add_split(meta, fastx.getName()), [ fastx ] ] }

    //
    // MODULE: Predict proteins for new species representatives
    //
    PYRODIGALGV(
        ch_split_species_reps_fna_gz
    )

    //
    // MODULE: Combine new + old rep FAA files
    //
    FIND_CONCATENATE(
        PYRODIGALGV.out.faa_gz
            .filter { meta, _faa_gz -> meta.id.contains("new_species_reps") }
            .map { _meta, faa_gz -> [ faa_gz ] }
            .collect()
            .map { tsv_gzs -> [ [ id:'new_species_reps_combined' ], tsv_gzs ] }
            .mix(
                PYRODIGALGV.out.faa_gz
                    .filter { meta, _faa_gz -> meta.id.contains("old_species_reps") }
                    .map { _meta, faa_gz -> [ faa_gz ] }
                    .collect()
                    .map { tsv_gzs -> [ [ id:'old_species_reps_combined' ], tsv_gzs ] }
            )
    )

    //
    // MODULE: Make a DIAMOND database from new + old species representatives
    //
    DIAMOND_MAKEDB(
        FIND_CONCATENATE.out.file_out,
        [],
        [],
        []
    )

    //
    // MODULE: Align new + old reps to new reps
    //
    DIAMOND_BLASTP_V_NEW(
        PYRODIGALGV.out.faa_gz,
        DIAMOND_MAKEDB.out.db.filter{ meta, _db -> meta.id.contains("new_species_reps") }.collect(),
        6,
        []
    )

    //
    // MODULE: Align new reps to old reps
    //
    DIAMOND_BLASTP_V_OLD(
        PYRODIGALGV.out.faa_gz.filter{ meta, _faa_gz -> meta.id.contains("new_species_reps") },
        DIAMOND_MAKEDB.out.db.filter{ meta, _db -> meta.id.contains("old_species_reps") }.collect(),
        6,
        []
    )

    //
    // MODULE: Align new + old reps to self
    //
    DIAMOND_BLASTPSELF(
        PYRODIGALGV.out.faa_gz,
    )

    //
    // MODULE: Calculate self scores
    //

    //
    // MODULE: Calculate normalized protein similarity scores
    //

    //
    // MODULE: Prune old scores + new scores to remove deprecated representatives
    //

    //
    // MODULE: Combine pruned scores
    //

    //
    // MODULE: Cluster new + old reps with MCL (family)
    //

    //
    // MODULE: Cluster new + old reps with MCL (subfamily)
    //

    //
    // MODULE: Cluster new + old reps with MCL (genus)
    //

    //
    // MODULE: Cluster new + old reps with MCL (subgenus)
    //
    
}

