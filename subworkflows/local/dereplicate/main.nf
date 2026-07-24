include { TRTRIMMER_SEQHASHER   } from '../../../modules/local/trtrimmer_seqhasher/main'
include { UHVDB_UNIQUEHASH      } from '../../../modules/local/uhvdb/uniquehash/main'
include { UHVDB_RENAME          } from '../../../modules/local/uhvdb/rename/main'
include { VCLUST_CSVTK          } from '../../../modules/local/vclust_csvtk/main'
include { KMERDB_LZANI_CSVTK    } from '../../../modules/local/kmerdb_lzani_csvtk/main'
include { FIND_CONCATENATE      } from '../../../modules/nf-core/find/concatenate/main'
include { MCL                   } from '../../../modules/local/mcl/main'
include { UHVDB_ANIREPS         } from '../../../modules/local/uhvdb/anireps/main'
include { rmEmptyFastAs         } from '../functions/main'

workflow DEREPLICATE {

    take:
    hq_confident_viruses_fna_gz
    classify_tsv_gz
    completeness_tsv_gz
    uhvdb_unique_viruses_fna_gz
    uhvdb_genomovars_gani_tsv_gz
    uhvdb_metadata_tsv_gz

    main:

    //
    // MODULE: Calculate the sequence hash for each virus
    //
    TRTRIMMER_SEQHASHER(
        rmEmptyFastAs(hq_confident_viruses_fna_gz)
    )

    //
    // MODULE: Identify new hashes and rename sequences with a UHVDB ID
    //
    UHVDB_UNIQUEHASH(
        TRTRIMMER_SEQHASHER.out.tsv_gz
            .map { _meta, tsv_gz -> [ tsv_gz ] }
            .collect()
            .map { tsv_gzs -> [ [ id:'new_unique_viruses' ], tsv_gzs ] },
        uhvdb_metadata_tsv_gz
    )

    //
    // MODULE: Rename sequence IDs in classify and completeness files
    //
    UHVDB_RENAME(
        classify_tsv_gz.mix(completeness_tsv_gz),
        UHVDB_UNIQUEHASH.out.id_map_tsv_gz.collect()
    )

    //
    // MODULE: Align new sequences to self with vClust
    //
    VCLUST_CSVTK(
        UHVDB_UNIQUEHASH.out.fna_gz,
        0.995,
        1.0
    )

    //
    // MODULE: Align new sequences to old sequences
    //
    KMERDB_LZANI_CSVTK(
        UHVDB_UNIQUEHASH.out.fna_gz,
        uhvdb_unique_viruses_fna_gz.map{ fna_gz -> [ [ id:"uhvdb_unique_viruses" ], fna_gz ] },
        0.995,
        1.0
    )

    //
    // MODULE: Combine gani files
    //
    FIND_CONCATENATE(
        KMERDB_LZANI_CSVTK.out.gani_tsv_gz
            .mix(VCLUST_CSVTK.out.gani_tsv_gz)
            .mix(uhvdb_genomovars_gani_tsv_gz.map { tsv_gz -> [ [ id:"uhvdb_genomovars" ], tsv_gz[0] ] })
            .map { _meta, tsv_gz -> [ tsv_gz] }.collect().map { tsv_gzs -> [ [ id: 'uhvdb_genomovars_gani' ], tsv_gzs ] }
    )

    //
    // MODULE: Cluster new and old sequences with MCL
    //
    MCL(
        FIND_CONCATENATE.out.file_out
    )

    //
    // MODULE: Identify genomovar reps
    //
    UHVDB_ANIREPS(
        UHVDB_UNIQUEHASH.out.fna_gz,
        uhvdb_unique_viruses_fna_gz,
        UHVDB_RENAME.out.tsv_gz.filter { meta, _tsv_gz -> meta.id == "combined_classify" },
        UHVDB_RENAME.out.tsv_gz.filter { meta, _tsv_gz -> meta.id == "combined_hqfilter" },
        MCL.out.mcl_gz,
        uhvdb_metadata_tsv_gz,
        'genomovars'
    )

    emit:
    new_fna_gz = UHVDB_ANIREPS.out.new_fna_gz.map { _meta, fna_gz -> def new_meta = [:]; new_meta.id = "new_genomovar_reps"; [ new_meta, fna_gz ] }
    old_fna_gz = UHVDB_ANIREPS.out.old_fna_gz.map { _meta, fna_gz -> def new_meta = [:]; new_meta.id = "old_genomovar_reps"; [ new_meta, fna_gz ] }
    info_tsv_gz = UHVDB_ANIREPS.out.tsv_gz
    classify_tsv_gz = UHVDB_RENAME.out.tsv_gz.filter { meta, _tsv_gz -> meta.id == "combined_classify" }
    completeness_tsv_gz = UHVDB_RENAME.out.tsv_gz.filter { meta, _tsv_gz -> meta.id == "combined_hqfilter" }
}
