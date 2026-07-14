include { ICTV_DOWNLOADER          } from '../../../modules/local/ictv/downloader/main'
include { PYRODIGALGV } from '../../../modules/local/pyrodigalgv/main'
include { DIAMOND_MAKEDB } from '../../../modules/nf-core/diamond/makedb/main.nf'
include { DIAMOND_BLASTP } from '../../../modules/nf-core/diamond/blastp/main.nf'
include { DIAMOND_BLASTPSELF } from '../../../modules/local/diamond/blastpself/main.nf'
include { UHVDB_SELFSCORE } from '../../../modules/local/uhvdb/selfscore/main.nf'
include { UHVDB_NORMSCORE } from '../../../modules/local/uhvdb/normscore/main.nf'
include { FIND_CONCATENATE } from '../../../modules/nf-core/find/concatenate/main'

workflow TAXONOMY {

    take:
    uhvdb_genomovar_reps_faa_gz
    classify_tsv_gz
    uhvdb_metadata_tsv_gz
    uhvdb_metadata_sylphtax_tsv_gz

    main:

    //
    // MODULE: Create a fasta file of ICTV VMR sequences from the provided Excel file (script)
    //
    ICTV_DOWNLOADER(
    )

    //
    // MODULE: Make a DIAMOND database of ICTV VMR sequences
    //
    DIAMOND_MAKEDB(
        ICTV_DOWNLOADER.out.faa_gz.map { faa -> [[id: 'ictv_cds'], faa] },
        [],
        [],
        []
    )

    //
    // MODULE: Align proteins to ICTV VMR sequences
    //
    DIAMOND_BLASTP(
        uhvdb_genomovar_reps_faa_gz,
        DIAMOND_MAKEDB.out.db.collect(),
        6,
        []
    )

    //
    // MODULE: Align to self
    //
    DIAMOND_BLASTPSELF(
        uhvdb_genomovar_reps_faa_gz
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
        DIAMOND_BLASTP.out.txt.map { meta, txt -> [ [ id: meta.id ], txt ] }
            .join(UHVDB_SELFSCORE.out.tsv_gz),
    )

    //
    // MODULE: Combine normalized protein similarity scores
    //
    FIND_CONCATENATE(
        UHVDB_NORMSCORE.out.tsv_gz.map{ _meta, tsv_gz -> [ tsv_gz ] }.mix(UHVDB_NORMSCORE).collect().map{ tsv_gzs -> [ [ id:'uhvbd_taxonomy' ], tsv_gzs ] }
    )

    //
    // MODULE: Create UHVDB taxonomy file
    //
    
}
