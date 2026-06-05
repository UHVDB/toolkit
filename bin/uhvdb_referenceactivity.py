#!/usr/bin/env python

### load packages
import argparse
import joblib
import math
import sys

import polars as pl
import pandas as pd
import numpy as np


def parse_args(args=None):
    description = "Assign activity tier to each reference genome."
    epilog = "Example usage: python uhvdb_referenceactivity.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-m",
        "--uhvdb_metadata",
        help="Path to UHVDB metadata TSV (e.g. uhvdb_v5_final_metadata.tsv.gz).",
    )
    parser.add_argument(
        "-c",
        "--coverm",
        help="Path to coverm TSV (e.g. coverm_contig.tsv.gz).",
    )
    parser.add_argument(
        "-s",
        "--sylph_tax",
        help="Path to Sylph taxonomy TSV (e.g. sylph_tax.tsv.gz).",
    )
    parser.add_argument(
        "-p",
        "--model_path",
        help="Path to model file (e.g. phage_activity_model_full.joblib).",
    )
    parser.add_argument(
        "-md",
        "--metadata_path",
        help="Path to metadata file (e.g. phage_model_metadata_full.joblib).",
    )
    parser.add_argument(
        "-sid",
        "--sample_id",
        help="Sample ID (e.g. samplesheet_se_fastq).",
    )
    parser.add_argument(
        "-g",
        "--group",
        help="Coassembly or co-analysis group (e.g. group1).",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV for Sylph (species_rep, final_virus_taxonomy, host_lineage; no header).",
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def calculate_phage_to_host(sylph_tax, sample_id):
    phage_host_ratio_lst = []

    # filter to virus rows
    virus_df = (
        pl.read_csv(sylph_tax, separator='\t', skip_rows=1, null_values=['NA'], new_columns=['clade_name', 'taxonomic_abundance', 'sequence_abundance', 'ani', 'coverage', 'virus_host'])
            .filter(pl.col('virus_host').is_not_null())
            .with_columns([
                pl.col('virus_host').str.replace_all(';', '|'),
                pl.lit(sample_id).alias('sample_id'),
                pl.col('clade_name').str.replace(r'.*vSPECIES-', '').str.replace(r'\|.*', '').cast(pl.Int64).alias('species_cluster_id'),
            ])
    )

    # filter to bacterial rows
    bac_df = (
        pl.read_csv(sylph_tax, separator='\t', skip_rows=1, null_values=['NA'], new_columns=['clade_name', 'taxonomic_abundance', 'sequence_abundance', 'ani', 'coverage', 'virus_host'])
            .filter(pl.col('clade_name').str.starts_with('d__Bacteria'))
    )

    # join at phage:host at level
    species_match = (
        virus_df
            .join(bac_df, left_on='virus_host', right_on='clade_name', how='inner')
            .with_columns([
                (pl.col('taxonomic_abundance') / pl.col('taxonomic_abundance_right')).alias('phage_host_ratio'),
                pl.col('clade_name').str.split('t__').list[1].alias('votu_rep'),
            ])
    )
    phage_host_ratio_lst.append(species_match)

    # join phage:host at genus level for viruses that did not match at species level
    genus_match = (
        virus_df
            .with_columns([pl.col('virus_host').str.split('|s__').list[0]])
            .filter(~pl.col('species_cluster_id').is_in(set(species_match['species_cluster_id'])))
            .join(bac_df, left_on='virus_host', right_on='clade_name', how='inner')
            .with_columns([
                (pl.col('taxonomic_abundance') / pl.col('taxonomic_abundance_right')).alias('phage_host_ratio'),
                pl.col('clade_name').str.split('t__').list[1].alias('votu_rep'),
            ])
    )
    phage_host_ratio_lst.append(genus_match)

    # combine all phage:host ratios
    phage_host_ratio_df = pl.concat(phage_host_ratio_lst)[['species_cluster_id', 'phage_host_ratio', 'virus_host']]

    return phage_host_ratio_df


def create_activity_input(coverm_df, genome_to_species_df, uhvdb_metadata_df, phage_host_ratio_df, sylph_tax_df):
    # aggregate to species level
    cf_metag_data_species = (
        coverm_df
            # filter to breadth ratio >= 0.6
            .filter(pl.col('breadth_ratio') >= 0.6)
            # join with genome to species mapping
            .join(genome_to_species_df, left_on='contig_id', right_on='uhvdb_id', how='left')
            # join with uhvdb metadata
            .join(uhvdb_metadata_df, on='species_cluster_id', how='left')
            # filter metadata to one sequence per hash
            .filter(pl.col('seq_name') == pl.col('seqhash_rep'))
            # filter metadata to sequences that are in the coverm contigs
            .filter(pl.col('contig_id') == pl.col('genomovar_rep'))
            # group by species cluster id, sample id, and group
            .group_by(['species_cluster_id', 'sample_id', 'group'])
            .agg([
                # count species members by checkv quality
                (pl.col('checkv_quality') == 'Complete').sum().alias('complete_count'),
                (pl.col('checkv_quality') == 'High-quality').sum().alias('high_quality_count'),
                # median number of geNomad virus hallmarks
                (pl.col('n_hallmarks')).median().alias('med_n_hallmarks'),
                # median ANI * AF for CheckV 
                ((pl.col('aai_id')/100) * pl.col('aai_af')).median().alias('med_aai_id_af'),
                # median viral and host genes CheckV
                (pl.col('viral_genes')).median().alias('med_viral_genes'),
                (pl.col('host_genes')).median().alias('med_host_genes'),
                # median BACPHLIP virulent score
                (pl.col('virulent').median()).alias('med_virulent_score'),
                # median number of integration related genes
                ((pl.col('phrog_integration_excision')).median() + (pl.col('empathi_integration')).median()).alias('med_integration_related'),
                # median number of genes per genome
                (pl.col('num_capsid').median()).alias('med_num_capsid'),
                (pl.col('num_tail').median()).alias('med_num_tail'),
                (pl.col('num_lysis').median()).alias('med_num_lysis'),
                (pl.col('mcp_hallmark').median()).alias('med_mcp_hallmark'),
                (pl.col('terl_hallmark').median()).alias('med_terL_hallmark'),
                (pl.col('portal_hallmark').median()).alias('med_portal_hallmark'),
                # read alignment metrics
                (pl.col('breadth').median()).alias('breadth'),
                (pl.col('breadth_ratio').median()).alias('breadth_ratio'),
                (pl.col('variance').median()).alias('variance'),
                (pl.col('trimmed_mean').median()).alias('trimmed_mean'),
            ])
            .with_columns([
                (pl.col('variance')/pl.col('trimmed_mean')).alias('variance_ratio'),
            ])
            .join(phage_host_ratio_df, on=['species_cluster_id'], how='left')
            .join(sylph_tax_df.select(['species_cluster_id', 'ani']), on=['species_cluster_id'], how='left')
            .unique(['species_cluster_id', 'sample_id'])
            .fill_null(0.00)
    )

    return cf_metag_data_species


def calculate_activity(activity_input_df, model_path, metadata_path):

    # =============================================================================
    # 1. LOAD MODEL AND METADATA
    # =============================================================================
    pipeline = joblib.load(model_path)
    metadata = joblib.load(metadata_path)

    # Extract info from metadata
    required_features = metadata["numeric_cols"]
    t90 = metadata["thresh_90"]
    t75 = metadata["thresh_75"]
    t50 = metadata["thresh_50"]

    # =============================================================================
    # 2. LOAD AND PREPROCESS NEW DATA
    # =============================================================================
    processed_results = activity_input_df

    # =============================================================================
    # 3. GENERATE PREDICTIONS
    # =============================================================================
    # Scikit-learn expects the exact columns in the exact order as training
    X_new = processed_results.select(required_features).to_pandas()
    X_new = X_new.replace([np.inf, -np.inf], np.nan)

    # Get probability of "Active" (Class 1)
    probs = pipeline.predict_proba(X_new)[:, 1]

    # =============================================================================
    # 4. CATEGORIZE BY CONFIDENCE TIERS
    # =============================================================================
    final_df = (
        processed_results
            .with_columns([
                pl.Series("activity_probability", probs)
            ])
            .with_columns([
                pl.when(pl.col("activity_probability") >= t90).then(pl.lit("High"))
                    .when(pl.col("activity_probability") >= t75).then(pl.lit("Medium"))
                    .when(pl.col("activity_probability") >= t50).then(pl.lit("Low"))
                    .otherwise(pl.lit("No Prediction"))
                    .alias("confidence_tier")
            ])
    )

    return final_df


def main(args=None):
    args = parse_args(args)

    # load inputs
    uhvdb_metadata_df = pl.read_csv(args.uhvdb_metadata, separator='\t')
    genome_to_species_df = uhvdb_metadata_df.select(['uhvdb_id', 'species_cluster_id']).unique()
    coverm_df = (
        pl.read_csv(args.coverm, separator='\t', new_columns=['contig_id', 'trimmed_mean', 'mean', 'variance', 'covered_bases', 'length'])
            .with_columns([
                    (pl.col('covered_bases')/pl.col('length')).alias('breadth'),
                    pl.lit(args.sample_id).alias('sample_id'),
                    pl.lit(args.group).alias('group'),
                ])
                .with_columns([
                    (1 - math.e**(-0.833 * pl.col('mean'))).alias('expected_breadth'),
                ])
                .with_columns([
                    (pl.col('breadth')/pl.col('expected_breadth')).alias('breadth_ratio'),
                ])
    )
    sylph_tax_df = (
        pl.read_csv(args.sylph_tax, separator='\t', skip_rows=1, null_values=['NA'], new_columns=['clade_name', 'taxonomic_abundance', 'sequence_abundance', 'ani', 'coverage', 'virus_host'])
            .filter(pl.col('clade_name').str.starts_with('Viruses'))
            .filter(pl.col('clade_name').str.contains('t__'))
            .with_columns([
                pl.col('clade_name').str.replace(r'.*vSPECIES-', '').str.replace(r'\|.*', '').cast(pl.Int64).alias('species_cluster_id'),
            ])
    )

    # calculate phage:host ratio
    phage_host_ratio_df = calculate_phage_to_host(args.sylph_tax, args.sample_id)

    # create activity input
    activity_input_df = create_activity_input(coverm_df, genome_to_species_df, uhvdb_metadata_df, phage_host_ratio_df, sylph_tax_df)

    # calculate activity
    activity_df = calculate_activity(activity_input_df, args.model_path, args.metadata_path)

    # combine activity with all other metadata
    activity_w_metadata_df = (
        coverm_df
            .filter(pl.col('breadth_ratio') >= 0.6)
            .join(genome_to_species_df, left_on='contig_id', right_on='uhvdb_id', how='left')
            .join(uhvdb_metadata_df, on='species_cluster_id', how='left')
            .filter(pl.col('seq_name') == pl.col('seqhash_rep'))
            .filter(pl.col('contig_id') == pl.col('genomovar_rep'))
            .with_columns([
                pl.col('ictv_class').fill_null('Unclassified'),
                pl.col('ictv_family').fill_null('Unclassified'),
                pl.col('host_lineage').fill_null('Unclassified'),
            ])
            .group_by(['species_cluster_id', 'sample_id', 'group'])
            .agg([
                # identify most common ictv class
                pl.col('ictv_class').mode().alias('most_common_ictv_class'),
                pl.col('ictv_family').mode().alias('most_common_ictv_family'),
                # identify most common uhvdb clusters
                pl.col('family_cluster_id').mode().alias('most_common_family_cluster_id'),
                pl.col('genus_cluster_id').mode().alias('most_common_genus_cluster_id'),
                # get the most common host taxonomy
                pl.col('host_lineage').mode().alias('most_common_host_taxonomy'),
                # get lifestyle information for detected viruses
                (pl.col('temperate').median()).alias('med_temperate_score'),
                pl.len().alias('num_genomovars_in_species'),
                ((pl.col('phrog_integration_excision') > 0) | (pl.col('empathi_integration') > 0)).sum().alias('count_integration_related'),
                ((pl.col('integration_status') == 'integrated').sum()).alias('count_integrated'),
                ((pl.col('checkv_quality') == 'Complete').sum()).alias('count_complete'),
                # get functional information
                pl.col('num_proteins').median().alias('med_protein_count'),
                (pl.col('num_uniprot_ips').median() / pl.col('num_proteins').median()).alias('mean_proportion_uniprot_ips'),
                (pl.col('num_capsid').median()).alias('med_num_capsid'),
                (pl.col('num_tail').median()).alias('med_num_tail'),
                (pl.col('num_lysis').median()).alias('med_num_lysis'),
                (pl.col('mcp_hallmark').median()).alias('med_mcp_hallmark'),
                (pl.col('terl_hallmark').median()).alias('med_terL_hallmark'),
                (pl.col('portal_hallmark').median()).alias('med_portal_hallmark'),
                ((pl.col('num_card') > 0 ).sum()).alias('count_card'),
                ((pl.col('num_vfdb') > 0 ).sum()).alias('count_vfdb'),
                # get genome information
                (pl.col('length').median()).alias('genome_length'),
                (pl.col('breadth').median()).alias('breadth'),
                (pl.col('breadth_ratio').median()).alias('breadth_ratio'),
                (pl.col('variance').median()).alias('variance'),
                (pl.col('trimmed_mean').median()).alias('trimmed_mean'),
            ])
            .with_columns([
                (pl.col('variance')/pl.col('trimmed_mean')).alias('variance_ratio'),
            ])
            .with_columns([
                pl.col('most_common_ictv_class').list[0],
                pl.col('most_common_ictv_family').list[0],
                pl.col('most_common_family_cluster_id').list[0],
                pl.col('most_common_genus_cluster_id').list[0],
                pl.col('most_common_host_taxonomy').list[0],
            ])
            .join(phage_host_ratio_df, on=['species_cluster_id'], how='left')
            .join(sylph_tax_df.select(['species_cluster_id', 'taxonomic_abundance', 'ani']), on=['species_cluster_id'], how='left')
            .join(activity_df[['species_cluster_id', 'activity_probability', 'confidence_tier', ]].with_columns([pl.col('species_cluster_id').cast(pl.Int64)]), on=['species_cluster_id'], how='left')
    )

    # write activity to tsv
    activity_w_metadata_df.write_csv(args.output, separator='\t')


if __name__ == "__main__":
    sys.exit(main())
