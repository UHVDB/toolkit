/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { PREPROCESS             } from '../subworkflows/local/preprocess'
include { ASSEMBLE               } from '../subworkflows/local/assemble'
include { CHECKV_DOWNLOAD        } from '../modules/local/checkv/download'
include { CLASSIFY               } from '../subworkflows/local/classify'
include { HQFILTER               } from '../subworkflows/local/hqfilter'
include { HCFILTER               } from '../subworkflows/local/hcfilter'
include { UHVDB_DOWNLOAD         } from '../modules/local/uhvdb/download'
include { DEREPLICATE            } from '../subworkflows/local/dereplicate'
include { ANICLUSTER             } from '../subworkflows/local/anicluster'
include { AAICLUSTER             } from '../subworkflows/local/aaicluster'
include { REFERENCEANALYZE       } from '../subworkflows/local/referenceanalyze'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_toolkit_pipeline'
include { add_split; rmEmptyFastAs             } from '../subworkflows/local/functions/main'
include { CSVTK_SEQKIT           } from '../modules/local/csvtk_seqkit/main'
include { SEQKIT_SPLIT2          } from '../modules/local/seqkit/split2/main'
include { PYRODIGALGV           } from '../modules/local/pyrodigalgv/main'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TOOLKIT {

    take:
    reads   // channel: [ [ meta ], read_1, read_2 ]
    sra     // channel: [ [ meta ], sra ]
    fastas  // channel: [ [ meta ], fna ]
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def ch_versions = channel.empty()
    def ch_multiqc_files = channel.empty()

    //
    // MODULE: Download UHVDB database
    //
    UHVDB_DOWNLOAD()
    // TODO: Change location to S3 bucket
    ch_uhvdb_metadata_tsv_gz = UHVDB_DOWNLOAD.out.metadata_tsv_gz.collect()
    ch_uhvdb_metadata_sylphtax_tsv_gz = UHVDB_DOWNLOAD.out.metadata_sylphtax_tsv_gz.collect()
    ch_uhvdb_unique_reps_fna_gz = UHVDB_DOWNLOAD.out.unique_reps_fna_gz.collect()
    ch_uhvdb_genomovars_gani_tsv_gz = UHVDB_DOWNLOAD.out.genomovars_gani_tsv_gz.collect()
    ch_uhvdb_species_gani_tsv_gz = UHVDB_DOWNLOAD.out.species_gani_tsv_gz.collect()
    ch_uhvdb_proteins_faa_gz = UHVDB_DOWNLOAD.out.proteins_faa_gz.collect()
    ch_uhvdb_proteinsimilarity_tsv_gz = UHVDB_DOWNLOAD.out.proteinsimilarity_tsv_gz.collect()
    ch_uhvdb_protein_annotations_tsv_gz = UHVDB_DOWNLOAD.out.protein_annotations_tsv_gz.collect()

    if ( params.run_update || params.run_analyze ) {
        //
        // SUBWORKFLOW: Download and preprocess reads
        //
        PREPROCESS(
            params.deacon_index_name,
            reads,
            sra
        )
        ch_spring = PREPROCESS.out.spring
    }

    if ( params.run_update || params.run_assembly_analyze ) {
        //
        // SUBWORKFLOW: Assemble reads into contigs
        //
        ASSEMBLE(
            fastas,
            PREPROCESS.out.spring
        )
        ch_spring = ch_spring.mix(ASSEMBLE.out.spring)
        fastas    = fastas.mix(ASSEMBLE.out.assembly_fna_gz)
    }

    
    if ( params.run_update || params.run_assembly_analyze ) {
        //
        // MODULE: Download UHVDB-CheckV database
        //
        CHECKV_DOWNLOAD()

        //
        // SUBWORKFLOW: Classify viruses in input fasta files
        //
        CLASSIFY(
            fastas,
            channel.fromPath(params.dtr_sequences_file).first(),
            CHECKV_DOWNLOAD.out.checkv_db
        )
    }

    if ( params.run_update ) {
        //
        // SUBWORKFLOW: Update CheckV's database and re-run Checkv to identify HQ viruses
        //
        HQFILTER(
            CLASSIFY.out.virus_fna_gz,
            CLASSIFY.out.complete_fna_gz,
            CLASSIFY.out.tsv_gz,
            CLASSIFY.out.checkv_db
        )

        //
        // SUBWORKFLOW: Identify confident viruses from HQ viruses
        //
        HCFILTER(
            HQFILTER.out.fna_gz,
            CLASSIFY.out.tsv_gz
        )

        //
        // SUBWORKFLOW: Dereplicate high-quality, confident viruses
        //
        DEREPLICATE(
            HCFILTER.out.fna_gz,
            CLASSIFY.out.combined_tsv_gz,
            HQFILTER.out.combined_tsv_gz,
            ch_uhvdb_unique_reps_fna_gz,
            ch_uhvdb_genomovars_gani_tsv_gz,
            ch_uhvdb_metadata_tsv_gz
        )

        //
        // SUBWORKFLOW: Cluster unique viruses at the species level
        //
        ANICLUSTER(
            DEREPLICATE.out.new_fna_gz,
            DEREPLICATE.out.classify_tsv_gz,
            DEREPLICATE.out.completeness_tsv_gz,
            DEREPLICATE.out.old_fna_gz,
            ch_uhvdb_species_gani_tsv_gz,
            ch_uhvdb_metadata_tsv_gz
        )

        //
        // SUBWORKFLOW: Cluster new species reps at the genus level
        //
        AAICLUSTER(
            ANICLUSTER.out.new_fna_gz,
            ANICLUSTER.out.old_fna_gz
        )

        //
        // MODULE: Extract new genomovar reps that are not species reps
        //
        CSVTK_SEQKIT(
            ANICLUSTER.out.tsv_gz.join(rmEmptyFastAs(ANICLUSTER.out.new_fna_gz))
        )

        //
        // SUBWORKFLOW: Cluster viruses at the family -> subgenus levels
        //

        //
        // MODULE: Split new genomovar reps into chunks
        //
        SEQKIT_SPLIT2(
            rmEmptyFastAs(CSVTK_SEQKIT.out.fna_gz)
        )
        ch_split_genomovar_reps_fna_gz = SEQKIT_SPLIT2.out.fastx
            .transpose()
            .map{ meta, fastx ->
                [ add_split(meta, fastx.getName()), [ fastx ] ] }

        //
        // MODULE: Predict proteins for new genomovar reps
        //
        PYRODIGALGV(
            rmEmptyFastAs(ch_split_genomovar_reps_fna_gz)
        )

        //
        // SUBWORKFLOW: Annotate viruses with taxonomy
        //
        
        //
        // MODULE: Download CRISPR spacer database
        //

        //
        // SUBWORKFLOW: Annotate viruses host using CRISPR spacers
        //

        //
        // MODULE: Download UHBDB database
        //

        //
        // SUBWORKFLOW: Annotate viruses hosts using PHIST
        //

        //
        // SUBWORKFLOW: Annotate viruses with functions
        //

        //
        // SUBWORKFLOW: Annotate viruses with lifestyles
        //

        //
        // SUBWORKFLOW: Update UHVDB with new viruses
        //

    }

    if ( params.run_analyze ) {
        //
        // SUBWORKFLOW: Analyze viruses
        //
        REFERENCEANALYZE(
            ch_spring,
            ch_uhvdb_unique_reps_fna_gz,
            ch_uhvdb_metadata_tsv_gz,
            ch_uhvdb_metadata_sylphtax_tsv_gz
        )
    }

    if ( params.run_assembly_analyze ) {
        //
        // SUBWORKFLOW: Analyze viruses using assembly data
        //
    }

    if ( params.run_instrain ) {
        //
        // SUBWORKFLOW: Analyze  + hosts using instrain
        //
    }

    if ( params.run_pilea ) {
        //
        // SUBWORKFLOW: Analyze growth rate using pilea
        //
    }

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'toolkit_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'toolkit'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )
    emit:multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
