#!/usr/bin/env python

import argparse
import polars as pl

pl.Config.set_streaming_chunk_size(10_000)

def parse_args(args=None):
    description = "Calculate AAI self-alignment score for a genome."
    epilog = "Example usage: python uhvdb_selfscore.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to TSV created by DIAMOND (should include self-alignments).",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV containing AAI self-alignment score.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def calculate_self_score(input, output):
    
    # write streaming code
    self_score = (
        pl.scan_csv(input, separator='\t', has_header=False, schema_overrides={'column_1': pl.Utf8, 'column_2': pl.Utf8, 'column_12': pl.Float32})
            .select(['column_1', 'column_2', 'column_12'])
            .rename({'column_1':'query', 'column_2':'reference', 'column_12':'bitscore'})
            .filter(pl.col('query') == pl.col('reference'))
            .with_columns([
                pl.col('query').str.replace(r'_\d+$', '').cast(pl.Categorical).alias('genome')
            ])
            .group_by(pl.col('genome'))
            .agg([
                pl.len().alias('genes'),
                pl.col('bitscore').sum().alias('selfscore')
            ])
            .sort('genome')
    )

    # write out parquet
    self_score.sink_csv(output, separator='\t', include_header=True)


def main(args=None):
    args = parse_args(args)

    # calculate self score
    calculate_self_score(args.input, args.output)

if __name__ == "__main__":
    main()
