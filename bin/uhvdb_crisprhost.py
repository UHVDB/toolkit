#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
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
    host_info = pl.read_csv(
        args.host_info, separator='\t'
    )

    # load spacerextractor output
    spacer_hits = (
        pl.read_csv(args.se_tsv, separator='\t')
            .filter(pl.col('N mismatches') <= 1)
            .with_columns([
                pl.col('Spacer id').str.split(':').list[0].alias('Genome'),
            ])
            .join(host_info, on='Genome', how='inner')
            [['Spacer id', 'Genome', 'Repr_taxonomy', 'Target id', 'Start', 'End', 'Strand', 'N mismatches']]
    )
    spacer_hits.write_csv(args.output + '.spacerextractor.tsv', separator='\t')

    (
        spacer_hits
            .group_by(['Target id', 'Repr_taxonomy'])
            .agg([pl.len().alias('connections')])
            .group_by('Target id')
            .agg([
                pl.col('connections').sum().alias('total_connections'),
                pl.col('connections').max().alias('max_connections'),
                pl.col("Repr_taxonomy").sort_by("connections", descending=True).first().alias('top_taxonomy')
            ])
            .with_columns([
                (pl.col('max_connections') / pl.col('total_connections')).alias('species_agreement'),
            ])
            .filter(pl.col('species_agreement') >= 0.7)
            .write_csv(args.output + '.crisprhost.tsv', separator='\t')
    )

if __name__ == "__main__":
    sys.exit(main())
