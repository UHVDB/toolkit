#!/usr/bin/env python

import argparse
import gzip

import polars as pl
pl.Config.set_streaming_chunk_size(10_000)

def parse_args(args=None):
    description = """
        Prune UHVDB's normalized AAI score graph to retain only intra-cluster connections above
        a rank-specific threshold.
    """
    epilog = "Example usage: python uhvdb_prune.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-g",
        "--graph",
        help="Path to TSV normalized AAI score graph.",
    )
    parser.add_argument(
        "-c",
        "--clusters",
        help="Path to MCL-generated clusters file from the previous taxonomic rank.",
    )
    parser.add_argument(
        "-t",
        "--threshold",
        help="Threshold for intra-cluster connections pruning.",
        type=float
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV containing the pruned AAI normalized score graph.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def load_mcl_clusters(mcl_path):
    """Load MCL dump (gzipped or plain) into member -> cluster_id map.

    MCL --abc output is one cluster per line with whitespace-separated members.
    """
    mcl_clusters = {}
    cluster_id = 0
    open_fn = gzip.open if mcl_path.endswith('.gz') else open
    with open_fn(mcl_path, 'rt') as mcl_file:
        for line in mcl_file:
            members = line.strip().split()
            if not members:
                continue
            cluster_id += 1
            for member in members:
                mcl_clusters[member] = cluster_id
    return mcl_clusters


def main(args=None):
    args = parse_args(args)

    mcl_clusters = load_mcl_clusters(args.clusters)

    # load graph
    graph = (
        pl.scan_csv(args.graph, separator='\t', has_header=False)
            .with_columns([
                pl.col('column_1').replace_strict(mcl_clusters, default='unassigned').alias('query_taxa'),
                pl.col('column_2').replace_strict(mcl_clusters, default='unassigned').alias('reference_taxa')
            ])
            .filter(
                (pl.col('query_taxa') == pl.col('reference_taxa')) &
                (pl.col('query_taxa') != 'unassigned') &
                (pl.col('column_3') >= args.threshold)
            )
            # MCL abc format expects only: node1, node2, weight
            .select(['column_1', 'column_2', 'column_3'])
    )

    graph.sink_csv(args.output, separator='\t', include_header=False)


if __name__ == "__main__":
    main()
