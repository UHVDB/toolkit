#!/usr/bin/env python

import argparse

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


def main(args=None):
    args = parse_args(args)

    # read mcl clusters to a dictionary
    mcl = (
        pl.read_csv(args.clusters, has_header=False, row_index_name='cluster_id', row_index_offset=1)
    )

    mcl_clusters = {}

    for row in mcl.iter_rows(named=True):
        for member in row['column_1'].split('\t'):
            mcl_clusters[member] = row['cluster_id']

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
