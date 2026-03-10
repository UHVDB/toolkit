#!/usr/bin/env python

import argparse
import gzip

import polars as pl

def parse_args(args=None):
    description = "Extract cluster reps from vClust clusters."
    epilog = "Example usage: python uhvdb_vclus_reps.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-m",
        "--mcl",
        help="Path to MCL clusters.",
    )
    parser.add_argument(
        "-n",
        "--unique",
        help="Path to TSV file containing unique sequence IDs.",
    )
    parser.add_argument(
        "-t",
        "--tsv",
        help="Path to the classify TSV file output by UHVDB/classify.",
    )
    parser.add_argument(
        "-c",
        "--completeness",
        help="Path to the completeness TSV file from running CheckV2.",
    )
    parser.add_argument(
        "-u",
        "--uhvdb_metadata",
        help="Path to the UHVDB metadata TSV file from previous version of UHVDB.",
    )
    parser.add_argument(
        "-r",
        "--output_reps",
        help="Output TSV with clusters that have been assigned a representative.",
    )
    parser.add_argument(
        "-l",
        "--cluster_info",
        help="Output TSV with vClust cluster info.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def load_mcl_clusters(mcl, unique):
    # assign sequences to mcl clusters
    clusters = {}

    cluster_id = 0
    with gzip.open(mcl, 'rt') as mcl_file:
        for line in mcl_file:
            cluster_id += 1
            for node in line.strip().split():
                clusters[node] = cluster_id

    # assign unclustered sequences to their own cluster
    with open(unique, 'r') as unique_file:
        for line in unique_file:
            sequence = line.strip().split()[0]
            if sequence not in clusters:
                cluster_id += 1
                clusters[sequence] = cluster_id

    return clusters


def load_metadata(classify_tsv, completeness, uhvdb_metadata, clusters):
    if uhvdb_metadata:
        df = pl.concat([
            pl.read_csv(classify_tsv, separator='\t', ignore_errors=True),
            pl.read_csv(uhvdb_metadata, separator='\t', ignore_errors=True)
        ])
    else:
        df = pl.read_csv(classify_tsv, separator='\t', ignore_errors=True)
    
    if 'original_id' not in df.columns:
        df = df.with_columns(pl.col('seq_name').alias('original_id'))
    
    mine_report = (
        # load mine report and join with uhvdb metadata
        df
            .join(
                pl.read_csv(completeness, separator='\t', columns=['contig_id', 'aai_expected_length'], ignore_errors=True),
                how='inner', left_on='original_id', right_on='contig_id'
            )
            # retain only sequences that are in clusters
            .filter(
                (pl.col('seq_name').is_in(clusters.keys()))
            )
            # create cluster_id and length columns
            .with_columns([
                pl.when(pl.col('contig_length').is_not_null())
                    .then(pl.col('contig_length'))
                    .when(pl.col('proviral_length').is_not_null())
                    .then(pl.col('proviral_length'))
                    .alias('length').cast(pl.Float64)
            ])
            .with_columns([pl.col('seq_name').replace_strict(clusters, default=None).alias('cluster_id')])
    )

    return mine_report

def main(args=None):
    args = parse_args(args)

    # vClust Cluster Reps 1
    # 1. identify median length for each cluster
    # 2. Assign singletons as vOTU reps
    # 3. Assign longest DTRs (> median length) as vOTU reps
    # 4. Assign linear genome with highest number of viral genes (tiebreaker: closest to expected AAI length) as vOTU reps
    # 5. Output vOTU reps
    # 6. Output vClust vOTU cluster information

    # load cluster assignments
    clusters = load_mcl_clusters(args.mcl, args.unique)

    # load sequence metadata
    mine_report = load_metadata(args.tsv, args.completeness, args.uhvdb_metadata, clusters)

    # 1. calculate median length amd size each cluster
    cluster_metrics = (
        mine_report.group_by('cluster_id').agg(
            [
                pl.col('length').median().alias('median_length'),
                pl.col('viral_genes').max().alias('max_viral_genes'),
                pl.col('seq_name').len().alias('num_seqs')
            ]
        )
    )

    mine_report_metrics = (
        mine_report
            .join(cluster_metrics, on='cluster_id', how='inner')
    )

    # 2. assign singletons as vOTU representatives
    singleton_clusters = set(
        cluster_metrics.filter(pl.col('num_seqs') == 1)['cluster_id']
    )

    cluster_reps = (
        mine_report
            .filter(pl.col('cluster_id').is_in(singleton_clusters))['seq_name', 'cluster_id']
    )

    # 3. assign longest DTRs as vOTU representatives (if > median length)
    dtr_cluster_reps = (
        mine_report_metrics
            .filter(
                (
                    (pl.col('completeness_method').str.contains('DTR'))
                ) &
                (~pl.col('cluster_id').is_in(cluster_reps['cluster_id']))
            )
            .sort('length', descending=True)
            .group_by('cluster_id', maintain_order=True)
            .first()['seq_name', 'cluster_id']
    )

    cluster_reps = pl.concat([cluster_reps, dtr_cluster_reps])

    # 4. Assign linear genome closest to expected AAI length with highest number of viral genes
    linear_cluster_reps = (
        mine_report_metrics
            .filter(
                (~pl.col('cluster_id').is_in(cluster_reps['cluster_id'])) &
                (pl.col('viral_genes') == pl.col('max_viral_genes'))
            )
            .with_columns([
                pl.col('aai_expected_length').cast(pl.String).str.replace('NA', pl.col('median_length')).cast(pl.Float64).alias('aai_expected_length'),
            ])
            .with_columns([
                (abs(pl.col('length').cast(pl.Float64) - pl.col('aai_expected_length').cast(pl.Float64))).alias('length_diff'),
            ])
            .sort(pl.col('length_diff'), descending=False)
            .group_by('cluster_id', maintain_order=True)
            .first()['seq_name', 'cluster_id']
    )

    cluster_reps = pl.concat([cluster_reps, linear_cluster_reps])

    # 5. Output vOTU representatives
    cluster_reps[['seq_name']].write_csv(args.output_reps)

    # 6. Output cluster information
    (
        mine_report_metrics
            [['seq_name', 'cluster_id', 'num_seqs', 'length', 'median_length', 'aai_expected_length', 'viral_genes', 'max_viral_genes', 'completeness_method', 'source_db']]
            .join(cluster_reps, on='cluster_id', how='full', suffix='_rep')
            .drop('cluster_id_rep')
            .rename({'seq_name_rep': 'votu_rep'})
            .write_csv(args.cluster_info, separator='\t')
    )


if __name__ == "__main__":
    main()
