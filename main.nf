#!/usr/bin/env nextflow

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT PLUGINS/FUNCTIONS/MODULES/SUBWORKFLOWS/WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
// PLUGINS
include { samplesheetToList } from 'plugin/nf-schema'

// FUNCTIONS
def validateInputSamplesheet (input) {
    def metas = input[1]

    // Check that multiple runs of the same sample are of the same datatype i.e. single-end / paired-end
    def endedness_ok = metas.collect{ meta -> meta.single_end }.unique().size == 1
    if (!endedness_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be of the same datatype i.e. single-end or paired-end: ${metas[0].id}")
    }
    // Check that multiple runs of the same sample are placed in the same group
    def grouping_ok = metas.collect{ meta -> meta.group }.unique().size == 1
    if (!grouping_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be placed into the same group: ${metas[0].id}")
    }
    // Check that multiple runs of the same sample are given different run ids
    def runs_ok   = metas.collect{ meta -> meta.run }.unique().size == metas.collect{ meta -> meta.run }.size
    if (!runs_ok) {
        error("Please check input samplesheet -> Multiple runs of a sample must be given a different run id: ${metas[0].id}")
    }
}

def rmNonMultiFastAs(ch_fastas, min) {
    def ch_nonempty_fastas = ch_fastas
        .filter { _meta, fasta ->
            try {
                file(fasta).countFasta( limit: min ) > (min - 1)
            } catch (java.util.zip.ZipException e) {
                log.debug "[rmNonMultiFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                true
            } catch (EOFException) {
                log.debug "[rmNonMultiFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
                false
            }
        }
    return ch_nonempty_fastas
}

// MODULES
include { UHVDB_TAXASPLIT           } from './modules/local/uhvdb/taxasplit'

// SUBWORKFLOWS
include { AAICLUSTER                } from './subworkflows/local/aaicluster'
include { ASSEMBLE                  } from './subworkflows/local/assemble'
include { ANICLUSTER                } from './subworkflows/local/anicluster'
include { CLASSIFY                  } from './subworkflows/local/classify'
include { CRISPRHOST                } from './subworkflows/local/crisprhost'
include { DATABASES                 } from './subworkflows/local/databases'
include { FUNCTION                  } from './subworkflows/local/function'
include { HCFILTER                  } from './subworkflows/local/hcfilter'
include { HQFILTER                  } from './subworkflows/local/hqfilter'
include { IPHOP                     } from './subworkflows/local/iphop'
include { LIFESTYLE                 } from './subworkflows/local/lifestyle'
include { PREPROCESS                } from './subworkflows/local/preprocess'
include { PHIST                     } from './subworkflows/local/phist'
include { TAXONOMY                  } from './subworkflows/local/taxonomy'
include { UPDATE                    } from './subworkflows/local/update'

// WORKFLOWS
// include { ANALYZE                   } from './workflows/local/analyze'
// include { ANNOTATE                  } from './workflows/local/annotate'
// include { COMPARE                   } from './workflows/local/compare'
// include { MINE                      } from './workflows/local/mine'
// include { UPDATE                    } from './workflows/local/update'

//-------------------------------------------
// PIPELINE: UHVDB
// inputs:
// - params.input
// - params.fastqs
// - params.fnas
// - params.virus_fnas
// outputs:
// - params.output_dir
// steps:
// - load inputs (various functions)
// - PREPROCESS_READS (subworkflow)
// - MINE (workflow)
// - ANNOTATE (workflow)
// - UPDATE (workflow)
// - ANALYZE (workflow)
// - COMPARE (workflow)
//-------------------------------------------
workflow {

    main:

    ch_input_fastqs_prefilt = channel.empty()
    ch_input_sra_prefilt    = channel.empty()
    ch_input_fastas         = channel.empty()
    ch_input_virus_fastas   = channel.empty()

    // Load input samplesheet (--input)
    if (params.input) {
        ch_samplesheet = channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
            .map { meta, fastq_1, fastq_2, _fna, _virus_fna ->
                    def sra         = meta.acc
                    meta.single_end = fastq_2 ? false : true
                    def no_fastq    = !fastq_1 && !fastq_2
                    if (meta.single_end) {
                        return [ meta + [ from_sra:false ], [ fastq_1 ], sra ]
                    } else if (!no_fastq) {
                        return [ meta + [ from_sra:false ], [ fastq_1, fastq_2 ], sra ]
                    } else {
                        return [ meta + [ from_sra:true ], [], sra ]
                    }
            }
            .multiMap { meta, fastqs, sra ->
                fastqs: [ meta, fastqs ]
                sra:    [ meta, sra ]
            }

        // validate samplesheet
        ch_samplesheet.fastqs
            .map { meta, fastq ->
                [ meta.id, meta, fastq ]
            }
            .groupTuple()
            .map { samplesheet -> validateInputSamplesheet(samplesheet) }

        ch_input_fastqs_prefilt = ch_input_fastqs_prefilt.mix(ch_samplesheet.fastqs)
        ch_input_sra_prefilt    = ch_input_sra_prefilt.mix(ch_samplesheet.sra)

        ch_input_fastas = ch_input_fastas.mix(
                channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
                .map { meta, _fastq_1, _fastq_2, fna, _virus_fna ->
                    return [ meta, fna ]
                }
                .filter { _meta, fna -> fna[0] }
        )

        ch_input_virus_fastas = ch_input_virus_fastas.mix(
                channel.fromList(samplesheetToList(params.input, "${projectDir}/assets/schema_input.json"))
                .map { meta, _fastq_1, _fastq_2, _fna, virus_fna ->
                    return [ meta, virus_fna ]
                }
                .filter { _meta, virus_fna -> virus_fna[0] }
        )
    }

    // Load fastq input (--fastqs)
    if ( params.fastqs ) {
        ch_input_fastqs_prefilt = ch_input_fastqs_prefilt.mix(
            channel.fromFilePairs(params.fastqs, size:-1)
            .map { meta, fastq ->
                def meta_new = [:]
                meta_new.id           = meta
                meta_new.bioproject   = meta
                meta_new.group        = meta
                meta_new.single_end   = fastq.size() == 1 ? true : false
                meta_new.from_sra     = false
                if ( meta_new.single_end ) {
                    return [ meta_new, [ fastq[0] ] ]
                } else {
                    return [ meta_new, [ fastq[0], fastq[1] ] ]
                }
            }
        )
    }

    // Filter out empty fastq channels
    ch_input_fastqs = ch_input_fastqs_prefilt.filter { _meta, fastqs -> fastqs[0] }
    ch_input_sras   = ch_input_sra_prefilt.filter { _meta, sra -> sra[0] }

    //-------------------------------------------
    // SUBWORKFLOW: PREPROCESS
    // inputs:
    // - [ [ meta ], [ read1.fastq.gz, read1.fastq.gz? ] ]
    // - [ [ meta ], acc ]
    // outputs:
    // - [ [ meta ], spring ]
    // steps:
    // - DEACON_INDEXFETCH (module)
    // - READ_DOWNLOAD (module)
    // - READ_PREPROCESS (module)
    //-------------------------------------------
    if ( params.run_assemble || params.run_referenceanalyze ) {
        PREPROCESS(
            ch_input_fastqs,
            ch_input_sras
        )
        ch_preprocessed_spring = PREPROCESS.out.preprocessed_spring
    }

    //-------------------------------------
    // Load assembly inputs (--fnas)
    //-------------------------------------
    if ( params.fnas ) {
        ch_input_fastas = ch_input_fastas.mix(
            channel.fromPath(params.fnas)
            .map { fasta ->
                def meta    = [:]
                meta.id     = fasta.getBaseName()
                meta.group  = fasta.getBaseName()
                return [ meta, fasta ]
            }
        )
    }

    //-------------------------------------------
    // SUBWORKFLOW: ASSEMBLE
    // inputs:
    // - [ [ meta ], reads.spring ]
    // outputs:
    // - [ [ meta ], grouped.spring ]
    // - [ [ meta ], assembly.fna.gz ]
    // steps:
    // - SPRING_CAT (module)
    // - MEGAHIT (module)
    //--------------------------------------------
    if ( params.run_assemble ) {
        ASSEMBLE(
            ch_preprocessed_spring
        )
        ch_assembly_fna_gz      = ASSEMBLE.out.assembly_fna_gz.map { meta, fna_gz -> meta.source_db = null; [ meta, fna_gz ] }
        ch_preprocessed_spring  = ch_preprocessed_spring.mix(ASSEMBLE.out.reads_spring)
    } else {
        ch_assembly_fna_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: DATABASES
    // outputs:
    // - [ genomad_db ]
    // - [ checkv_db ]
    // steps:
    // - GENOMAD_DOWNLOADDATABASE (module)
    // - CHECKV_DOWNLOAD (module)
    //-------------------------------------------
    DATABASES()

    //-------------------------------------------
    // SUBWORKFLOW: CLASSIFY
    // inputs:
    // - [ [ meta ], assembly.fna.gz ]
    // outputs:
    // - [ [ meta ], virus_mq_plus.fna.gz ]
    // - [ [ meta ], uhvdb_virus_classify.tsv.gz ]
    // - [ [ meta ], uhvdb_completeness.tsv.gz ]
    // steps:
    // - GENOMAD_DOWNLOADDATABASE (module)
    // - ATB_GENOMAD (module)
    // - ENA_GENOMAD (module)
    // - NCBI_GENOMAD (module)
    // - LOGAN_GENOMAD (module)
    // - SPIRE_GENOMAD (module)
    // - LOCAL_SEQKIT_SPLIT2 (module)
    // - LOCAL_GENOMAD (module)
    // - CHECKV (module)
    // - VIRALVERIFY (module)
    // - UHVDB_VIRUSCLASSIFY (module)
    // - UHVDB_CATHEADER (module)
    // - UHVDB_CATNOHEADER (module)
    //--------------------------------------------
    if ( params.run_classify ) {
        CLASSIFY(
            ch_input_fastas.mix(ch_assembly_fna_gz),
            DATABASES.out.genomad_db,
            DATABASES.out.checkv_db
        )
        ch_mq_plus_viruses_fna_gz   = CLASSIFY.out.mq_plus_viruses_fna_gz
        ch_classify_tsv_gz          = CLASSIFY.out.classify_tsv_gz
    } else {
        ch_mq_plus_viruses_fna_gz   = ch_input_fastas.mix(ch_assembly_fna_gz)
        ch_classify_tsv_gz          = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: HQFILTER
    // inputs:
    // - [ [ meta ], virus.fna.gz ]
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // - [ [ meta ], uhvdb_completeness.tsv.gz ]
    // - [ checkv_db ]
    // outputs:
    // - [ [ meta ], hq_virus.part_*.fna.gz ]
    // steps:
    // - UHVDB_COMPLETEGENOMES (module)
    // - TRTRIMMER_COMPLETE (module)
    // - VCLUST_ALL2ALL (module)
    // - CHECKV_VCLUST (module)
    // - CHECKV_UPDATE (module)
    // - CHECKV_ENDTOEND2 (module)
    // - UHVDB_HQFILTER (module)
    // - TRTRIMMER_HQ (module)
    // - SEQHASHER (module)
    // - UHVDB_UNIQUE (module)
    // - UNIQUE_DEREP (subworkflow)
    // - GENOMOVAR_DEREP (subworkflow)
    // - UHVDB_UNCERTAIN (module)
    // - GENOMAD_DOWNLOADHALLMARKS (module)
    // - GENOMAD_HMMSEARCH (module)
    // - UHVDB_HCFILTER (module)
    // - UHVDB_CATHEADER (module)
    // - UHVDB_CATNOHEADER (module)
    //--------------------------------------------
    if ( params.run_hqfilter ) {
        HQFILTER(
            ch_mq_plus_viruses_fna_gz,
            ch_classify_tsv_gz,
            DATABASES.out.checkv_db
        )
        ch_hq_virus_fna_gz = HQFILTER.out.hq_viruses_fna_gz
        ch_hqfilter_tsv_gz = HQFILTER.out.hqfilter_tsv_gz
    } else {
        ch_hq_virus_fna_gz = ch_mq_plus_viruses_fna_gz
        ch_hqfilter_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: HCFILTER
    // inputs:
    // - [ [ meta ], hq_virus.part_*.fna.gz ]
    // - [ [ meta ], uhvdb_classify.tsv.gz ]
    // outputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // - [ [ meta ], seqhasher.tsv.gz ]
    // - [ [ meta ], unique.tsv.gz ]
    // - [ [ meta ], genomovar.tsv.gz ]
    // steps:
    // - TRTRIMMER (module)
    // - SEQHASHER (module)
    // - UHVDB_UNIQUE (module)
    // - UNIQUE_DEREP (subworkflow)
    // - GENOMOVAR_DEREP (subworkflow)
    // - UHVDB_UNCERTAIN (module)
    // - GENOMAD_DOWNLOADHALLMARKS (module)
    // - GENOMAD_HMMSEARCH (module)
    // - UHVDB_HCFILTER (module)
    // - UHVDB_CATHEADER (module)
    // - UHVDB_CATNOHEADER (module)
    //--------------------------------------------
    if ( params.run_hcfilter ) {
        HCFILTER(
            ch_hq_virus_fna_gz,
            ch_classify_tsv_gz
        )
        ch_new_hq_hc_virus_fna_gz   = HCFILTER.out.new_fna_gz
        ch_all_hq_hc_virus_fna_gz   = HCFILTER.out.all_fna_gz
        ch_hcfilter_tsv_gz          = HCFILTER.out.tsv_gz
        ch_new_classify_tsv_gz      = HCFILTER.out.classify_tsv_gz
    } else {
        ch_new_hq_hc_virus_fna_gz   = ch_hq_virus_fna_gz
        ch_all_hq_hc_virus_fna_gz   = ch_hq_virus_fna_gz
        ch_hcfilter_tsv_gz          = channel.empty()
        ch_new_classify_tsv_gz      = ch_classify_tsv_gz
    }

    //-------------------------------------------
    // SUBWORKFLOW: TAXONOMY
    // inputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // - [ [ meta ], uhvdb_virus_classify.tsv.gz ]
    // outputs:
    // - [ [ meta ], taxonomy.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - DIAMOND_BLASTP (module)
    // - DIAMOND_BLASTPSELF (module)
    // - PROTEINSIMILARITY_NORMSCORE (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    if ( params.run_taxonomy ) {
        TAXONOMY(
            ch_new_hq_hc_virus_fna_gz,
            ch_new_classify_tsv_gz,
            params.vmr_url
        )
        ch_taxonomy_tsv_gz = TAXONOMY.out.tsv_gz
    } else 
    {
        ch_taxonomy_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: PHIST
    // inputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], phist.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - PHIST_BUILD (module)
    // - PHIST_DATASETS (module)
    // - UHVDB_CATHEADER (module)
    // - PHIST_NOHITS (module)
    //--------------------------------------------
    if ( params.run_phist ) {
        PHIST(
            ch_new_hq_hc_virus_fna_gz
        )
        ch_nophist_fna_gz = PHIST.out.fna_gz
        ch_phist_tsv_gz = PHIST.out.tsv_gz
    } else {
        // ch_nophist_fna_gz = ch_new_hq_hc_virus_fna_gz
        ch_phist_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: CRISPRHOST
    // inputs:
    // - [ [ meta ], hq_hc_virus.phist_nohits.fna.gz ]
    // outputs:
    // - [ [ meta ], crisprhost.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - SPACEREXTRACTOR_CREATETARGETDB (module)
    // - SPACEREXTRACTOR_MAPTOTARGET (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    if ( params.run_crisprhost ) {
        CRISPRHOST(
            ch_nophist_fna_gz
        )
        ch_nocrisprhost_fna_gz = CRISPRHOST.out.fna_gz
        ch_crisprhost_tsv_gz = CRISPRHOST.out.tsv_gz
    } else {
        // ch_nocrisprhost_fna_gz = ch_nophist_fna_gz
        ch_crisprhost_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: IPHOP
    // inputs:
    // - [ [ meta ], hq_hc_virus.crispr_nohits.fna.gz ]
    // outputs:
    // - [ [ meta ], iphop.tsv.gz ]
    // steps:
    // - IPHOP_DOWNLOAD (module)
    // - SEQKIT_SPLIT (module)
    // - IPHOP_PREDICT (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    if ( params.run_iphop ) {
        IPHOP(
            ch_nocrisprhost_fna_gz
        )
        iphop_genus_tsv_gz = IPHOP.out.genus_tsv_gz
        iphop_genome_tsv_gz = IPHOP.out.genome_tsv_gz
    } else {
        iphop_genus_tsv_gz = channel.empty()
        iphop_genome_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: FUNCTION
    // inputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], uniprot.tsv.gz ]
    // - [ [ meta ], phrogs.tsv.gz ]
    // - [ [ meta ], empathi.tsv.gz ]
    // - [ [ meta ], dgrs.tsv.gz ]
    // - [ [ meta ], amrfinder.tsv.gz ]
    // - [ [ meta ], vfdb.tsv.gz ]
    // - [ [ meta ], defensefinder.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - PYRODIGAL-GV (module) save FNA for instrain
    // - UHVDB_PROTEINHASH (module)
    // - SEQKIT_SPLIT2 (module)
    // - BAKTA_PROTEINS (module) with --very-sensitive diamond versus UniProt50 DIAMOND
    // - FOLDSEEK (module) only for proteins without uniprot hit
    // - INTERPROSCAN (module) only for proteins without uniprot hit
    // - PHAROKKA (module)
    // - PHOLD (module) only for proteins without a phrog
    // - EMPATHI (module)
    // - DIAMOND_CARD (module)
    // - DIAMOND_VFDB (module)
    // - DEFENSEFINDER (module)
    // - DGRSCAN (module)
    // - UHVDB_CATHEADER (module)
    // - UHVDB_CATNOHEADER (module)
    //--------------------------------------------
    if ( params.run_function ) {
        FUNCTION(
            ch_new_hq_hc_virus_fna_gz,
            ch_new_classify_tsv_gz
        )
        ch_protein2hash_tsv_gz = FUNCTION.out.protein2hash_tsv_gz
        ch_protein_faa_gz = FUNCTION.out.protein_faa_gz
        ch_protein_fna_gz = FUNCTION.out.protein_fna_gz
        // ch_dgrscan_tsv_gz = FUNCTION.out.dgrscan_tsv_gz
        ch_bakta_tsv_gz = FUNCTION.out.bakta_tsv_gz
        ch_foldseek_tsv_gz = FUNCTION.out.foldseek_tsv_gz
        ch_interproscan_tsv_gz = FUNCTION.out.interproscan_tsv_gz
        ch_card_tsv_gz = FUNCTION.out.card_tsv_gz
        ch_vfdb_tsv_gz = FUNCTION.out.vfdb_tsv_gz
        ch_defensefinder_tsv_gz = FUNCTION.out.defensefinder_tsv_gz
        ch_pharokka_tsv_gz = FUNCTION.out.pharokka_tsv_gz
        ch_phold_tsv_gz = FUNCTION.out.phold_tsv_gz
        ch_empathi_csv_gz = FUNCTION.out.empathi_csv_gz
    } else {
        ch_protein2hash_tsv_gz = channel.empty()
        ch_protein_faa_gz = channel.empty()
        ch_protein_fna_gz = channel.empty()
        ch_dgrscan_tsv_gz = channel.empty()
        ch_bakta_tsv_gz = channel.empty()
        ch_foldseek_tsv_gz = channel.empty()
        ch_interproscan_tsv_gz = channel.empty()
        ch_card_tsv_gz = channel.empty()
        ch_vfdb_tsv_gz = channel.empty()
        ch_defensefinder_tsv_gz = channel.empty()
        ch_pharokka_tsv_gz = channel.empty()
        ch_phold_tsv_gz = channel.empty()
        ch_empathi_csv_gz = channel.empty()
    }

    //-------------------------------------------
    // SUBWORKFLOW: LIFESTYLE
    // inputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // - [ [ meta ], uhvdb_virus_classify.tsv.gz ]
    // - [ [ meta ], phrogs.tsv.gz ]
    // - [ [ meta ], empathi.tsv.gz ]
    // outputs:
    // - [ [ meta ], lifestyle.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - BACPHLIP (module)
    // - UHVDB_LIFESTYLE (module) with input from classify (strong integration), phrogs and bacphlip (confident), empathi (unknown)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    if ( params.run_lifestyle ) {
        LIFESTYLE(
            ch_new_hq_hc_virus_fna_gz,
            ch_new_classify_tsv_gz,
            ch_pharokka_tsv_gz,
            ch_phold_tsv_gz,
            ch_empathi_csv_gz,
            ch_protein2hash_tsv_gz
        )
        ch_lifestyle_tsv_gz = LIFESTYLE.out.tsv_gz
    } else {
        ch_lifestyle_tsv_gz = channel.empty()
    }

    //-------------------------------------------
    // MODULE: UHVDB_TAXASPLIT
    // inputs:
    // - [ [ meta ], unique_virus.fna.gz ]
    // - [ [ meta ], virus_summary.tsv.gz ]
    // outputs:
    // - [ [ meta ], unique_virus.taxa*.fna.gz ]
    // steps:
    // - Split fasta by taxa (script)
    // - Cleanup (script)
    //-------------------------------------------
    if ( params.run_anicluster || params.run_aaicluster ) {
        UHVDB_TAXASPLIT(
            ch_new_hq_hc_virus_fna_gz,
            ch_new_classify_tsv_gz
        )
        ch_taxa_split_fna_gz = rmNonMultiFastAs(
            UHVDB_TAXASPLIT.out.fna_gzs
                .map { _meta, fna_gzs -> fna_gzs }
                .flatten()
                .map { fna_gz ->
                    def taxa = fna_gz.getBaseName().toString() =~ /taxa([^\.]+)\.fna/
                    [ [ id: fna_gz.getBaseName().replace(".fna", ""), taxa: taxa[0][1] ], fna_gz ]
                },
                1
        )
    } else {
        // ch_taxa_split_fna_gz = ch_new_hq_hc_virus_fna_gz
    }

    //-------------------------------------------
    // SUBWORKFLOW: ANICLUSTER
    // inputs:
    // - [ [ meta ], hq_hc_virus.genomovar_reps.fna.gz ]
    // - [ [ meta ], uhvdb_virus_classify.tsv.gz ]
    // outputs:
    // - [ [ meta ], aniclust.tsv.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // steps:
    // - SEQKIT_SPLIT2 (module)
    // - VCLUST_NEW2ALL (module)
    // - MCL (module)
    // - UHVDB_ANIREPS (module)
    //--------------------------------------------
    if ( params.run_anicluster ) {
        ANICLUSTER(
            ch_taxa_split_fna_gz,
            ch_new_classify_tsv_gz,
            ch_hqfilter_tsv_gz
        )
    }


    //-------------------------------------------
    // SUBWORKFLOW: AAICLUSTER
    // inputs:
    // - [ [ meta ], species_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], aniclust.tsv.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - BACPHLIP (module)
    // - UHVDB_LIFESTYLE (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    // if ( params.run_aaicluster ) {
    //     AAICLUSTER(
    //         ch_species_reps_fna_gz
    //     )
    // }

    //-------------------------------------------
    // SUBWORKFLOW: UPDATE
    // inputs:
    // - [ [ meta ], mq_plus_viruses.fna.gz ]
    // - [ [ meta ], hq_viruses_seqhasher.tsv.gz ]
    // - [ [ meta ], hq_viruses_unique.fna.gz ]
    // - [ [ meta ], hq_viruses_unique.tsv.gz ]
    // - [ [ meta ], classify_rename.classify.tsv.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - BACPHLIP (module)
    // - UHVDB_LIFESTYLE (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
    if ( params.run_update ) {
        UPDATE(
            CLASSIFY.out.mq_plus_viruses_fna_gz,
            HCFILTER.out.seqhasher_tsv_gz,
            HCFILTER.out.hq_viruses_unique_fna_gz,
            HCFILTER.out.hq_viruses_unique_tsv_gz,
            HCFILTER.out.hq_viruses_genomovars_fna_gz,
            HCFILTER.out.hq_viruses_genomovars_tsv_gz,
        )
    }

    //-------------------------------------------
    // SUBWORKFLOW: REFERENCEANALYZE
    // inputs:
    // - [ [ meta ], species_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], aniclust.tsv.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - BACPHLIP (module)
    // - UHVDB_LIFESTYLE (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------

    //-------------------------------------------
    // SUBWORKFLOW: ASSEMBLYANALYZE
    // inputs:
    // - [ [ meta ], species_reps.fna.gz ]
    // outputs:
    // - [ [ meta ], aniclust.tsv.gz ]
    // - [ [ meta ], species_reps.fna.gz ]
    // steps:
    // - SEQKIT_SPLIT (module)
    // - BACPHLIP (module)
    // - UHVDB_LIFESTYLE (module)
    // - UHVDB_CATHEADER (module)
    //--------------------------------------------
}
