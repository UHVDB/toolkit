include { SPRING_CAT        } from '../../../modules/local/spring_cat'
include { SPRING_MEGAHIT    } from '../../../modules/local/spring_megahit'

workflow ASSEMBLE {
    take:
    fastas
    spring

    main:

    // Identify samples with an input assembly
    def lst_input_fasta_ids = []
    fastas.map { meta, _fasta -> lst_input_fasta_ids.add(meta.id) }

    // Create channel from input spring
    def ch_spring = spring

    if ( params.include_coassembly ) {
        // group and set group as new id
        ch_coassembly_spring = spring
            .map { meta, _spring ->
                def grouping        = [:]
                grouping.group      = meta.group
                grouping.single_end = meta.single_end
                grouping.from_sra   = meta.from_sra

                [ grouping, meta, _spring ]
            }
            .groupTuple( by: 0, sort:'deep' )
            .filter { _grouping, _meta, _springs ->
                _springs.size() > 1
            }
            .map { grouping, meta, _spring ->
                def meta_new                = [:]
                meta_new.id                 = "${grouping.group}_coassembly".toString()
                meta_new.bioproject          = meta.source_db[0]
                meta_new.group              = grouping.group
                meta_new.single_end         = grouping.single_end
                meta_new.from_sra           = grouping.from_sra
                return [ meta_new, _spring.flatten() ]
            }

        //
        // MODULE: Combine SPRING archives for coassembly
        //
        SPRING_CAT(
            ch_coassembly_spring
        )

        // Add coassembly spring to channel
        ch_spring = ch_spring.mix(SPRING_CAT.out.spring)
    }

    //
    // MODULE: Assemble samples with megahit
    //
    SPRING_MEGAHIT(
        ch_spring.filter { meta, _spring -> !lst_input_fasta_ids.contains(meta.id) } // Only assemble samples without an input assembly
    )

    emit:
    spring              = ch_spring
    assembly_fna_gz     = SPRING_MEGAHIT.out.fna_gz
}

