include { ICTV_VMRTOFASTA          } from '../../../modules/local/ictv/vmrtofasta/main'

workflow TAXONOMY {

    take:
    spring
    uhvdb_unique_reps_fna_gz
    uhvdb_metadata_tsv_gz
    uhvdb_metadata_sylphtax_tsv_gz
    ictv_vmr_xlsx

    main:

    //
    // MODULE: Create a fasta file of ICTV VMR sequences from the provided Excel file (script)∂
    //
    ICTV_VMRTOFASTA(
        ictv_vmr_xlsx
    )    
    
}
