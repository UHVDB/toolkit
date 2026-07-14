#!/usr/bin/env python

import argparse
import gzip
import sys
from pathlib import Path

import polars as pl


def parse_args(args=None):
    description = "Generate cluster assignments for UHVDB at multiple taxonomic ranks."
    epilog = "Example usage: python uhvdb_aaicluster.py --species-reps species_reps.tsv --family family.mcl.gz -o output.tsv"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "--species-reps",
        required=True,
        help="Path to species representatives ID file (one ID per line, no header).",
    )
    parser.add_argument(
        "--family",
        help="Path to gzipped MCL family cluster file.",
    )
    parser.add_argument(
        "--subfamily",
        help="Path to gzipped MCL subfamily cluster file.",
    )
    parser.add_argument(
        "--genus",
        help="Path to gzipped MCL genus cluster file.",
    )
    parser.add_argument(
        "--subgenus",
        help="Path to gzipped MCL subgenus cluster file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        help="Output TSV file with cluster assignments.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


### function to load mcl clusters into a DataFrame
def load_mcl_clusters(mcl, seq_id):
    # assign sequences to mcl clusters
    clusters = {}

    cluster_id = 0
    if mcl is not None:
        with gzip.open(mcl, 'rt') as mcl_file:
            for line in mcl_file:
                cluster_id += 1
                for node in line.strip().split():
                    clusters[node] = cluster_id

    # assign unclustered sequences to their own cluster
    with open(seq_id, 'r') as seqid_file:
        for line in seqid_file:
            sequence = line.strip()
            if sequence not in clusters:
                cluster_id += 1
                clusters[sequence] = cluster_id

    # convert to a DataFrame
    clusters_df = pl.DataFrame({
        'uhvdb_id': list(clusters.keys()),
        'cluster_id': list(clusters.values())
    })

    return clusters_df


def main(args=None):
    args = parse_args(args)
    
    # Process each rank
    ranks = {
        'family': args.family,
    }
    if args.subfamily != '':
        ranks['subfamily'] = args.subfamily
    if args.genus != '':
        ranks['genus'] = args.genus
    if args.subgenus != '':
        ranks['subgenus'] = args.subgenus

    for rank in ['family', 'subfamily', 'genus', 'subgenus']:
        # Parse MCL file
        if rank in ranks:
            genome_to_cluster = load_mcl_clusters(ranks[rank], args.species_reps)
        else:
            genome_to_cluster = load_mcl_clusters(None, args.species_reps)

        # combine cluster assignments across ranks
        df = genome_to_cluster.rename({'cluster_id': f'{rank}_cluster_id'})
        if 'combined_df' in locals():
            combined_df = combined_df.join(df, on='uhvdb_id', how='inner')
        else:
            combined_df = df

    # Write output
    combined_df.sort('uhvdb_id').write_csv(args.output, separator='\t', include_header=True)

if __name__ == "__main__":
    sys.exit(main())
