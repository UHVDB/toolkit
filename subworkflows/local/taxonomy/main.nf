/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// MODULES
include { DIAMOND_BLASTP                } from '../../../modules/local/diamond/blastp'
include { DIAMOND_BLASTPSELF            } from '../../../modules/local/diamond/blastpself'
include { DIAMOND_MAKEDB                } from '../../../modules/local/diamond/makedb'
include { ICTV_VMRTOFASTA               } from '../../../modules/local/ictv/vmrtofasta'
include { PROTEINSIMILARITY_SELFSCORE   } from '../../../modules/local/proteinsimilarity/selfscore'
include { PROTEINSIMILARITY_NORMSCORE   } from '../../../modules/local/proteinsimilarity/normscore'
include { PYRODIGALGV                   } from '../../../modules/local/pyrodigalgv'
include { SEQKIT_SPLIT2                 } from '../../../modules/local/seqkit/split2'
include { UHVDB_CATHEADER               } from '../../../modules/local/uhvdb/catheader'
include { UHVDB_TAXONOMY                } from '../../../modules/local/uhvdb/taxonomy'

workflow TAXONOMY {

    take:
    virus_fna_gz    // channel: [ [ meta ], fna.gz ]
    classify_tsv_gz // channel: [ [ meta ], tsv.gz ]
    vmr_url         // channel: [ vmr.xlsx ]

    main:

    ch_ictv_vmr = channel.fromPath(vmr_url)
        .map { xlsx ->
            [ [ id: "${xlsx.getBaseName()}" ], xlsx ]
        }

    //-------------------------------------------
    // MODULE: SEQKIT_SPLIT
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // outputs:
    // - [ [ meta ], [ virus.part_*.fna.gz ... ] ]
    // steps:
    // - Split sequences (script)
    //--------------------------------------------
    SEQKIT_SPLIT2(
        virus_fna_gz,
        params.taxonomy_split_size
    )
    ch_split_fna_gz = SEQKIT_SPLIT2.out.fastas_gz
        .map { _meta, fna_gzs -> fna_gzs }
        .flatten()
        .map { fna_gz ->
            [ [ id: fna_gz.getBaseName().replace(".fasta", "") ], fna_gz ]
        }

    def vmr_dmnd = params.vmr_dmnd ? file(params.vmr_dmnd).exists() : false

    // Prepare ICTV DIAMOND database
    if (!vmr_dmnd) {
        //-------------------------------------------
        // SUBWORKFLOW: ICTV_VMRTOFASTA
        // inputs:
        // - [ "ictv_vmr.xlsx" ]
        // outputs:
        // - [ ictv_vmr.fna.gz ]
        // steps:
        // - Process VMR (script)
        // - Download VMR FNA (script)
        // - Compress (script)
        // - Cleanup (script)
        //-------------------------------------------
        ICTV_VMRTOFASTA(
            ch_ictv_vmr
        )

        //-------------------------------------------
        // SUBWORKFLOW: DIAMOND_MAKEDB
        // inputs:
        // - [ ictv_vmr.fna.gz ]
        // outputs:
        // - [ [ meta ], ictv_vmr.dmnd]
        // steps:
        // - Convert FNA to FAA (script)
        // - Create DIAMOND DB (script)
        // - Cleanup (script)
        //-------------------------------------------
        DIAMOND_MAKEDB(
            ICTV_VMRTOFASTA.out.fna_gz
        )
        ch_vmr_dmnd = DIAMOND_MAKEDB.out.dmnd
    } else {
        ch_vmr_dmnd = channel.fromPath(params.vmr_dmnd)
            .map { dmnd ->
                [ [ id: "${dmnd.getBaseName()}" ], dmnd ]
            }
    }

    //-------------------------------------------
    // SUBWORKFLOW: DIAMOND_BLASTP
    // inputs:
    // - [ [ meta ], virus.part_*.fna.gz ]
    // outputs:
    // - [ [ meta ], virus.diamond_blastp.part_*.tsv.gz ]
    // - [ [ meta ], virus.pyrodigalgv.part_*.faa.gz ]
    // steps:
    // - Convert FNA to FAA (script)
    // - Run DIAMOND (script)
    // - Compress (script)
    //-------------------------------------------
    DIAMOND_BLASTP(
        ch_split_fna_gz.combine(ch_vmr_dmnd.map { _meta, dmnd -> dmnd }),
    )

    //-------------------------------------------
    // SUBWORKFLOW: DIAMOND_BLASTPSELF
    // inputs:
    //  - [ [ meta ], virus.pyrodigalgv.part_*.faa.gz ]
    // outputs:
    // - [ [ meta ], virus.diamond_self.part_*.tsv.gz]
    // steps:
    // - Make self DB (script)
    // - Run DIAMOND (script)
    // - Compress (script)
    // - Cleanup (script)
    //-------------------------------------------
    DIAMOND_BLASTPSELF(
        DIAMOND_BLASTP.out.faa_gz
    )

    //-------------------------------------------
    // SUBWORKFLOW: PROTEINSIMILARITY_SELFSCORE
    // inputs:
    //  - [ [ meta ], virus.diamond_self.part_*.tsv.gz]
    // outputs:
    // - [ [ meta ], virus.selfscore.part_*.tsv.gz]
    // steps:
    // - Calculate self score (script)
    // - Compress (script)
    //-------------------------------------------
    PROTEINSIMILARITY_SELFSCORE(
        DIAMOND_BLASTPSELF.out.tsv_gz
    )

    //-------------------------------------------
    // SUBWORKFLOW: PROTEINSIMILARITY_NORMSCORE
    // inputs:
    //  - [ [ meta ], virus.diamond_self.part_*.tsv.gz, virus.diamond_blastp.part_*.tsv.gz ]
    // outputs:
    // - [ [ meta ], virus.normscore.part_*.tsv.gz]
    // steps:
    // - Calculate normalized bitscore (script)
    // - Compress (script)
    //-------------------------------------------
    ch_normscore_input = PROTEINSIMILARITY_SELFSCORE.out.tsv_gz.combine(DIAMOND_BLASTP.out.tsv_gz, by:0)
    PROTEINSIMILARITY_NORMSCORE(
        ch_normscore_input
    )

    //-------------------------------------------
    // MODULE: UHVDB_CATHEADER
    // inputs:
    // - [ [ meta ], virus.normscore.part_*.tsv.gz]
    // outputs:
    // - [ [ meta ], normscore.tsv.gz ]
    // steps:
    // - Print header line (script)
    // - Print non-header lines (script)
    // - Compress (script)
    //--------------------------------------------
    ch_catheader_input = PROTEINSIMILARITY_NORMSCORE.out.tsv_gz.map { _meta, tsv_gz -> tsv_gz }.collect().map { tsv_gz -> [ [ id:'normscore' ], tsv_gz, 1, 'tsv.gz' ] }
    UHVDB_CATHEADER(
        ch_catheader_input,
        "${params.output_dir}/${params.new_release_id}/uhvdb/taxonomy"
    )

    //-------------------------------------------
    // MODULE: UHVDB_TAXONOMY
    // inputs:
    // - [ [ meta ], normscore.tsv.gz ]
    // - [ [ meta ], classify.tsv.gz ]
    // outputs:
    // - [ [ meta ], taxonomy.tsv.gz ]
    // steps:
    // - Assign taxonomy (script)
    // - Compress (script)
    //--------------------------------------------
    UHVDB_TAXONOMY(
        UHVDB_CATHEADER.out.combined,
        classify_tsv_gz,
        ch_ictv_vmr
    )

    emit:
    tsv_gz = UHVDB_TAXONOMY.out.tsv_gz
}
