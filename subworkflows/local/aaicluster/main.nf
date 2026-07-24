include { SEQKIT_SPLIT2                             } from '../../../modules/local/seqkit/split2/main'
include { rmEmptyFastAs; add_split                  } from '../functions/main'
include { PYRODIGALGV                               } from '../../../modules/local/pyrodigalgv/main'
include { FIND_CONCATENATE                          } from '../../../modules/nf-core/find/concatenate/main'
include { DIAMOND_MAKEDB                            } from '../../../modules/nf-core/diamond/makedb/main'
include { DIAMOND_BLASTP as DIAMOND_BLASTP_V_NEW    } from '../../../modules/nf-core/diamond/blastp/main.nf'
include { DIAMOND_BLASTP as DIAMOND_BLASTP_V_OLD    } from '../../../modules/nf-core/diamond/blastp/main.nf'
include { DIAMOND_BLASTPSELF                        } from '../../../modules/local/diamond/blastpself/main'
include { UHVDB_SELFSCORE                           } from '../../../modules/local/uhvdb/selfscore/main'
include { UHVDB_NORMSCORE                           } from '../../../modules/local/uhvdb/normscore/main'
include { FIND_CONCATENATE as FIND_CONCATENATE_NORMSCORE } from '../../../modules/nf-core/find/concatenate/main'
include { UHVDB_REPGRAPH                            } from '../../../modules/local/uhvdb/repgraph/main'
include { MCL as MCL_FAMILY                         } from '../../../modules/local/mcl/main'
include { UHVDB_PRUNE as UHVDB_PRUNE_SUBFAMILY      } from '../../../modules/local/uhvdb/prune/main'
include { MCL as MCL_SUBFAMILY                      } from '../../../modules/local/mcl/main'
include { UHVDB_PRUNE as UHVDB_PRUNE_GENUS          } from '../../../modules/local/uhvdb/prune/main'
include { MCL as MCL_GENUS                          } from '../../../modules/local/mcl/main'
include { UHVDB_PRUNE as UHVDB_PRUNE_SUBGENUS       } from '../../../modules/local/uhvdb/prune/main'
include { MCL as MCL_SUBGENUS                       } from '../../../modules/local/mcl/main'
include { UHVDB_AAICLUSTER                          } from '../../../modules/local/uhvdb/aaicluster/main'

workflow AAICLUSTER {

    take:
    new_species_reps_fna_gz
    old_species_reps_fna_gz
    proteinsimilarity_tsv_gz

    main:

    //
    // MODULE: Split new + old species reps into chunks
    //
    SEQKIT_SPLIT2(
        rmEmptyFastAs(new_species_reps_fna_gz.mix(old_species_reps_fna_gz)),
        10000
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
    UHVDB_SELFSCORE(
        DIAMOND_BLASTPSELF.out.txt,
    )

    //
    // MODULE: Calculate normalized protein similarity scores
    //
    UHVDB_NORMSCORE(
        DIAMOND_BLASTP_V_OLD.out.txt.map { meta, txt -> [ meta.id, [ id: "${meta.id}.new2old" ], txt ] }
            .mix(DIAMOND_BLASTP_V_NEW.out.txt.map { meta, txt -> [ meta.id, [ id: "${meta.id}.new2new" ], txt ] })
            .combine(UHVDB_SELFSCORE.out.tsv_gz.map { meta, tsv_gz -> [ meta.id, tsv_gz ] }, by: 0)
            .map { _id, meta, txt, tsv_gz -> [ meta, txt, tsv_gz ] }
    )

    //
    // MODULE: Combine normalized protein similarity scores
    //
    FIND_CONCATENATE_NORMSCORE(
        UHVDB_NORMSCORE.out.tsv_gz.map{ _meta, tsv_gz -> [ tsv_gz ] }.mix(proteinsimilarity_tsv_gz).collect().map{ tsv_gzs -> [ [ id:'uhvdb_normscore' ], tsv_gzs ] }
    )

    //
    // MODULE: Filter normscore to only current species reps
    //
    UHVDB_REPGRAPH(
        FIND_CONCATENATE_NORMSCORE.out.file_out,
        new_species_reps_fna_gz.combine(old_species_reps_fna_gz).map { meta, new_fna_gz, _meta2, old_fna_gz -> [ meta, new_fna_gz, old_fna_gz ] },
    )

    //
    // MODULE: Cluster new + old reps with MCL (family)
    //
    MCL_FAMILY(
        UHVDB_REPGRAPH.out.tsv_gz,
    )

    //
    // MODULE: Prune to subfamily graph
    //
    UHVDB_PRUNE_SUBFAMILY(
        UHVDB_REPGRAPH.out.tsv_gz.map { _meta, tsv_gz -> [ [ id: 'subfamily' ], tsv_gz ] }
            .combine(MCL_FAMILY.out.mcl_gz.map { _meta, mcl_gz -> [ mcl_gz ] }),
        32,
    )

    //
    // MODULE: Cluster new + old reps with MCL (subfamily)
    //
    MCL_SUBFAMILY(
        UHVDB_PRUNE_SUBFAMILY.out.tsv_gz,
    )

    //
    // MODULE: Prune to genus graph
    //
    UHVDB_PRUNE_GENUS(
        UHVDB_PRUNE_SUBFAMILY.out.tsv_gz.map { _meta, tsv_gz -> [ [ id: 'genus' ], tsv_gz ] }
            .combine(MCL_SUBFAMILY.out.mcl_gz.map { _meta, mcl_gz -> [ mcl_gz ] }),
        65,
    )

    //
    // MODULE: Cluster new + old reps with MCL (genus)
    //
    MCL_GENUS(
        UHVDB_PRUNE_GENUS.out.tsv_gz,
    )
    
    //
    // MODULE: Prune to subgenus graph
    //
    UHVDB_PRUNE_SUBGENUS(
        UHVDB_PRUNE_GENUS.out.tsv_gz.map { _meta, tsv_gz -> [ [ id: 'subgenus' ], tsv_gz ] }
            .combine(MCL_GENUS.out.mcl_gz.map { _meta, mcl_gz -> [ mcl_gz ] }),
        80,
    )

    //
    // MODULE: Cluster new + old reps with MCL (subgenus)
    //
    MCL_SUBGENUS(
        UHVDB_PRUNE_SUBGENUS.out.tsv_gz,
    )

    //
    // MODULE: Create a cluster file for AAI clusters
    //
    UHVDB_AAICLUSTER(
        new_species_reps_fna_gz.map { _meta, fna_gz -> [ [ id:'uhvdb_aaicluster' ], fna_gz ] },
        old_species_reps_fna_gz,
        MCL_FAMILY.out.mcl_gz,
        MCL_SUBFAMILY.out.mcl_gz,
        MCL_GENUS.out.mcl_gz,
        MCL_SUBGENUS.out.mcl_gz
    )

    emit:
    tsv_gz = UHVDB_AAICLUSTER.out.tsv_gz
    faa_gz = PYRODIGALGV.out.faa_gz.filter{ meta, _faa_gz -> meta.id.contains("new_species_reps") }
}

