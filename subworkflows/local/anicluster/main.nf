include { KMERDB_LZANI_CSVTK    } from '../../../modules/local/kmerdb_lzani_csvtk/main'
include { VCLUST_CSVTK          } from '../../../modules/local/vclust_csvtk/main'
include { FIND_CONCATENATE      } from '../../../modules/nf-core/find/concatenate/main'
include { UHVDB_REPGRAPH        } from '../../../modules/local/uhvdb/repgraph/main'
include { MCL                   } from '../../../modules/local/mcl/main'
include { UHVDB_ANIREPS         } from '../../../modules/local/uhvdb/anireps/main'

workflow ANICLUSTER {

    take:
    new_genomovars_fna_gz
    classify_tsv_gz
    completeness_tsv_gz
    old_genomovars_fna_gz
    uhvdb_species_gani_tsv_gz
    uhvdb_metadata_tsv_gz

    main:

    //
    // MODULE: Align new sequences to old sequences
    //
    KMERDB_LZANI_CSVTK(
        new_genomovars_fna_gz,
        old_genomovars_fna_gz
    )

    //
    // MODULE: Align new sequences to self
    //
    VCLUST_CSVTK(
        new_genomovars_fna_gz
    )

    //
    // MODULE: Combine gani files
    //
    FIND_CONCATENATE(
        KMERDB_LZANI_CSVTK.out.gani_tsv_gz
            .mix(VCLUST_CSVTK.out.gani_tsv_gz)
            .mix(uhvdb_species_gani_tsv_gz.map { tsv_gz -> [ [ id:"uhvdb_genomovars" ], tsv_gz[0] ] })
            .map { _meta, tsv_gz -> [ tsv_gz] }.collect().map { tsv_gzs -> [ [ id: 'uhvdb_species_gani' ], tsv_gzs ] }
    )

    //
    // MODULE: Filter graphs to contain only new reps
    //
    UHVDB_REPGRAPH(
        FIND_CONCATENATE.out.file_out,
        new_genomovars_fna_gz.combine(old_genomovars_fna_gz).map { _meta, new_fna_file, _meta_old, old_fna_file -> [ [ id:'new_genomovar_reps' ], new_fna_file, old_fna_file ] }
    )

    //
    // MODULE: Cluster new and old sequences with MCL
    //
    MCL(
        UHVDB_REPGRAPH.out.tsv_gz
    )

    //
    // MODULE: Identify species reps
    //
    UHVDB_ANIREPS(
        new_genomovars_fna_gz,
        old_genomovars_fna_gz.map { _meta, old_fna_gz-> [ old_fna_gz ] },
        classify_tsv_gz,
        completeness_tsv_gz,
        MCL.out.mcl_gz,
        uhvdb_metadata_tsv_gz
    )

    emit:
    new_fna_gz = UHVDB_ANIREPS.out.new_fna_gz.map { _meta, fna_gz -> def new_meta = [:]; new_meta.id = "new_species_reps"; [ new_meta, fna_gz ] }
    old_fna_gz = UHVDB_ANIREPS.out.old_fna_gz.map { _meta, fna_gz -> def new_meta = [:]; new_meta.id = "old_species_reps"; [ new_meta, fna_gz ] }
    tsv_gz = UHVDB_ANIREPS.out.tsv_gz
}