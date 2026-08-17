/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { UHVDB_DOWNLOAD                } from '../modules/local/uhvdb/download'
include { UHVDB_ANNOTATIONS_PARQUET     } from '../modules/local/uhvdb/annotationsparquet'
include { DEACON_INDEXFETCH             } from '../modules/local/deacon/indexfetch'
include { CHECKV_DOWNLOAD               } from '../modules/local/checkv/download'
include { SRACHA_FASTP_DEACON_MEGAHIT   } from '../modules/local/sracha_fastp_deacon_megahit'
include { FASTP_DEACON_MEGAHIT          } from '../modules/local/fastp_deacon_megahit'
include { ASSEMBLY                      } from '../subworkflows/local/assembly'
include { CLASSIFY                      } from '../subworkflows/local/classify'
include { HQFILTER                      } from '../subworkflows/local/hqfilter'
include { DEREPLICATE                   } from '../subworkflows/local/dereplicate'
include { ANICLUSTER                    } from '../subworkflows/local/anicluster'
include { AAICLUSTER                    } from '../subworkflows/local/aaicluster'
include { rmEmptyFastAs; add_split      } from '../subworkflows/local/functions/main'
include { CSVTK_SEQKIT                  } from '../modules/local/csvtk_seqkit/main'
include { SEQKIT_SPLIT2                 } from '../modules/local/seqkit/split2/main'
include { PYRODIGALGV                   } from '../modules/local/pyrodigalgv/main'
include { TAXONOMY                      } from '../subworkflows/local/taxonomy/main'
include { CRISPRHOST                    } from '../subworkflows/local/crisprhost/main'
include { PHISTHOST                     } from '../subworkflows/local/phisthost/main'
include { FUNCTION                      } from '../subworkflows/local/function/main'
include { LIFESTYLE                     } from '../subworkflows/local/lifestyle/main'
include { UPDATE                        } from '../subworkflows/local/update/main'
include { REFERENCEANALYZE              } from '../subworkflows/local/referenceanalyze'
include { paramsSummaryMap              } from 'plugin/nf-schema'
include { paramsSummaryMultiqc          } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText        } from '../subworkflows/local/utils_nfcore_toolkit_pipeline'
include { MULTIQC                       } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow TOOLKIT {

    take:
    reads   // channel: [ [ meta ], read_1, read_2 ]
    sras    // channel: [ [ meta ], sra ]
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
    ch_uhvdb_metadata_tsv_gz = UHVDB_DOWNLOAD.out.metadata_tsv_gz.collect()
    ch_uhvdb_metadata_sylphtax_tsv_gz = UHVDB_DOWNLOAD.out.metadata_sylphtax_tsv_gz.collect()
    ch_uhvdb_unique_reps_fna_gz = UHVDB_DOWNLOAD.out.unique_reps_fna_gz.collect()
    ch_uhvdb_genomovars_gani_tsv_gz = UHVDB_DOWNLOAD.out.genomovars_gani_tsv_gz.collect()
    ch_uhvdb_species_gani_tsv_gz = UHVDB_DOWNLOAD.out.species_gani_tsv_gz.collect()
    ch_uhvdb_proteins_faa_gz = UHVDB_DOWNLOAD.out.proteins_faa_gz.collect()
    ch_uhvdb_proteinsimilarity_tsv_gz = UHVDB_DOWNLOAD.out.proteinsimilarity_tsv_gz.collect()
    ch_uhvdb_protein_annotations_tsv_gz = UHVDB_DOWNLOAD.out.protein_annotations_tsv_gz.collect()

    //
    // MODULE: Convert protein annotations TSV to parquet for fast gene-coverage filtering
    //
    UHVDB_ANNOTATIONS_PARQUET(ch_uhvdb_protein_annotations_tsv_gz)
    ch_uhvdb_protein_annotations_parquet = UHVDB_ANNOTATIONS_PARQUET.out.protein_annotations_parquet.collect()

    //
    // MODULE: Download deacon index
    //
    DEACON_INDEXFETCH()
    ch_deacon_idx = DEACON_INDEXFETCH.out.idx.first()


    if ( params.run_update  ) {
        //
        // MODULE: Download UHVDB-CheckV database
        //
        CHECKV_DOWNLOAD()
        ch_checkv_db = CHECKV_DOWNLOAD.out.checkv_db.first()

        //
        // SUBWORKFLOW: Assemble reads
        //
        ASSEMBLY(
            reads,
            sras,
            ch_deacon_idx
        )
        ch_fastas = fastas.mix(ASSEMBLY.out.fna_gz)
        
        // Create channel from DTR sequences file
        def ch_dtr_sequences = params.dtr_sequences_file
            ? channel.fromPath(params.dtr_sequences_file).first()
            : channel.value([]).first()

        //
        // SUBWORKFLOW: Classify viruses in input fasta files
        //
        CLASSIFY(
            ch_fastas,
            ch_dtr_sequences,
            ch_checkv_db
        )

        //
        // SUBWORKFLOW: Update CheckV's database and re-run Checkv to identify HQ viruses
        //
        HQFILTER(
            CLASSIFY.out.confident_fna_gz,
            CLASSIFY.out.complete_fna_gz,
            CLASSIFY.out.classify_tsv_gz,
            ch_checkv_db
        )

        //
        // SUBWORKFLOW: Dereplicate high-quality, confident viruses
        //
        DEREPLICATE(
            HQFILTER.out.fna_gz,
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
        // SUBWORKFLOW: Cluster new species reps at the family -> subgenus level
        //
        AAICLUSTER(
            ANICLUSTER.out.new_fna_gz,
            ANICLUSTER.out.old_fna_gz,
            ch_uhvdb_proteinsimilarity_tsv_gz
        )

        //
        // MODULE: Extract new genomovar reps that are not species reps
        // Join to DEREPLICATE new genomovar FASTA (meta.id new_genomovar_reps), not
        // ANICLUSTER.new_fna_gz (remapped to new_species_reps), so the join keys match
        // and invert-match can select non-species reps from the full genomovar set.
        //
        CSVTK_SEQKIT(
            ANICLUSTER.out.tsv_gz.join(rmEmptyFastAs(DEREPLICATE.out.new_fna_gz)),
            "--tabs --filter '( \$uhvdb_id == \$species_rep )' | csvtk cut --tabs -f uhvdb_id --out-delimiter '\t'",
            "--invert-match",
            "genomovar_not_species_reps"
        )

        //
        // MODULE: Split new genomovar reps into chunks
        //
        SEQKIT_SPLIT2(
            rmEmptyFastAs(CSVTK_SEQKIT.out.fna_gz),
            10000
        )
        ch_split_genomovar_reps_fna_gz = SEQKIT_SPLIT2.out.fastx
            .transpose()
            .map{ meta, fastx ->
                [ add_split(meta, fastx.getName()), [ fastx ] ] }

        //
        // MODULE: Predict proteins for new genomovar reps
        //
        PYRODIGALGV(
            ch_split_genomovar_reps_fna_gz
        )

        //
        // SUBWORKFLOW: Annotate viruses with taxonomy
        //
        TAXONOMY(
            AAICLUSTER.out.faa_gz.mix(PYRODIGALGV.out.faa_gz),
            DEREPLICATE.out.classify_tsv_gz
        )


        //
        // SUBWORKFLOW: Annotate viruses host using CRISPR spacers
        //
        CRISPRHOST(
            AAICLUSTER.out.split_fna_gz.mix(ch_split_genomovar_reps_fna_gz)
        )

        //
        // SUBWORKFLOW: Annotate viruses hosts using PHIST
        //
        PHISTHOST(
            AAICLUSTER.out.split_fna_gz.mix(ch_split_genomovar_reps_fna_gz)
        )

        //
        // SUBWORKFLOW: Annotate viruses with functions
        //
        FUNCTION(
            AAICLUSTER.out.faa_gz.mix(PYRODIGALGV.out.faa_gz),
            ch_uhvdb_protein_annotations_tsv_gz
        )

        //
        // SUBWORKFLOW: Annotate viruses with lifestyles
        //

        LIFESTYLE(
            DEREPLICATE.out.new_fna_gz,
            DEREPLICATE.out.classify_tsv_gz,
            FUNCTION.out.pharokka_tsv_gz,
            FUNCTION.out.phold_tsv_gz,
            FUNCTION.out.empathi_csv_gz,
            FUNCTION.out.protein2hash_tsv_gz,
            ch_uhvdb_metadata_tsv_gz
        )

        //
        // SUBWORKFLOW: Update UHVDB with new viruses
        //
        UPDATE(
            DEREPLICATE.out.seqhasher_tsv_gz,
            DEREPLICATE.out.mapping_tsv_gz,
            DEREPLICATE.out.classify_tsv_gz,
            DEREPLICATE.out.completeness_tsv_gz,
            DEREPLICATE.out.hcfilter_tsv_gz,
            DEREPLICATE.out.info_tsv_gz,
            ANICLUSTER.out.tsv_gz,
            AAICLUSTER.out.tsv_gz,
            TAXONOMY.out.taxonomy_tsv_gz,
            CRISPRHOST.out.crisprhost_tsv_gz,
            PHISTHOST.out.phisthost_tsv_gz,
            FUNCTION.out.protein2hash_tsv_gz,
            FUNCTION.out.bakta_tsv_gz,
            FUNCTION.out.foldseek_tsv_gz,
            FUNCTION.out.interproscan_tsv_gz,
            FUNCTION.out.card_tsv_gz,
            FUNCTION.out.vfdb_tsv_gz,
            FUNCTION.out.pharokka_tsv_gz,
            FUNCTION.out.phold_tsv_gz,
            FUNCTION.out.empathi_csv_gz,
            ch_uhvdb_metadata_tsv_gz,
            ch_uhvdb_protein_annotations_tsv_gz,
            TAXONOMY.out.ictv_hits_tsv_gz,
            CRISPRHOST.out.crispr_tsv_gz,
            PHISTHOST.out.phist_tsv_gz,
            UHVDB_DOWNLOAD.out.ictv_hits_tsv_gz,
            UHVDB_DOWNLOAD.out.crispr_tsv_gz,
            UHVDB_DOWNLOAD.out.phist_tsv_gz
        )

    }

    if ( params.run_analyze ) {
        //
        // SUBWORKFLOW: Analyse viruses
        //
        REFERENCEANALYZE(
            reads,
            sras,
            ch_deacon_idx,
            ch_uhvdb_unique_reps_fna_gz,
            ch_uhvdb_metadata_tsv_gz,
            ch_uhvdb_metadata_sylphtax_tsv_gz,
            ch_uhvdb_protein_annotations_parquet
        )
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
