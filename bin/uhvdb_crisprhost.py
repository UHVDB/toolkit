#!/usr/bin/env python

import argparse
import sys

import polars as pl


def parse_args(args=None):
    description = "Parse spacerextractor output to identify host species."
    epilog = "Example usage: python uhvdb_crisprhost.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--host_info",
        help="Path to TSV file linking host genome ID to taxonomy.",
    )
    parser.add_argument(
        "-t",
        "--se_tsv",
        help="Path to TSV file output spacerextractor_map.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing host taxonomy prediction.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # load host info
    host_info = (
        pl.read_csv(args.host_info, separator='\t')
            .rename({'id':'original_id'})
            .with_columns([
                pl.when(pl.col('original_id').str.starts_with(r'GC')).then(pl.col('original_id').str.split('.').list[0])
                    .otherwise(pl.col('original_id'))
                    .alias('id'),
            ])
    )

    # load spacerextractor output
    spacer_hits = (
        pl.read_csv(args.se_tsv, separator='\t')
            .filter(pl.col('N mismatches') <= 1)
            .with_columns([
            pl.when(pl.col('Spacer id').str.starts_with(r'GC')).then(pl.col('Spacer id').str.split('.').list[0])
                .when(pl.col('Spacer id').str.contains('_HD.')).then(pl.col('Spacer id').str.replace(r'\..*;', ';'))
                .when(pl.col('Spacer id').str.contains('.CD')).then(pl.col('Spacer id').str.replace(r'\..*;', ';'))
                .when(pl.col('Spacer id').str.contains('.UC')).then(pl.col('Spacer id').str.replace(r'\..*;', ';'))
                .when(pl.col('Spacer id').str.contains('.FI')).then(pl.col('Spacer id').str.replace(r'\..*;', ';'))
                .otherwise(pl.col('Spacer id'))
                .alias('id'),
            ])
            .with_columns([
                pl.col('id').str.replace(r'_CRISPR.*', '')
            ])
            .join(host_info, on='id', how='inner')
            [['Spacer id', 'id', 'species', 'genus', 'family', 'Target id', 'Start', 'End', 'Strand', 'N mismatches']]
            .rename({'Target id': 'uhvdb_id'})
    )
    spacer_hits.write_csv(args.output + '.spacerextractor.tsv', separator='\t')

    combined_host_df_lst = []
    for rank in ['species', 'genus', 'family']:
        consensus_df = (
            spacer_hits
                .group_by(['uhvdb_id', rank])
                .agg([pl.len().alias('connections')])
                .group_by('uhvdb_id')
                .agg([
                    pl.col('connections').sum().alias('total_connections'),
                    pl.col('connections').max().alias('max_connections'),
                    pl.col(rank).sort_by("connections", descending=True).first().alias('top_taxonomy')
                ])
                .with_columns([
                    (pl.col('max_connections') / pl.col('total_connections')).alias('agreement'),
                    pl.lit(rank).alias('rank')
                ])
                .filter(pl.col('agreement') >= 0.7)
        )
        combined_host_df_lst.append(consensus_df)

    (
        pl.concat(combined_host_df_lst)
            .write_csv(args.output + '.crisprhost.tsv', separator='\t')
    )


if __name__ == "__main__":
    sys.exit(main())
