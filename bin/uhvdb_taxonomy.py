#!/usr/bin/env python

import argparse
import gzip
import sys

import polars as pl


def parse_args(args=None):
    description = "Compile UHVDB lifestyle data."
    epilog = "Example usage: python uhvdb_lifestyle.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-t",
        "--classify_tsv",
        help="Path to TSV file output UHVDB/classify.",
    )
    parser.add_argument(
        "-n",
        "--normscore_tsv",
        help="Path to TSV file output by normscore.",
    )
    parser.add_argument(
        "-v",
        "--vmr_url",
        help="Path to VMR URL.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing taxonomy information for each virus.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # load classify tsv
    classify = (
        pl.read_csv(args.classify_tsv, separator='\t', null_values=["NA"], columns=['seq_name', 'taxonomy'])
            .with_columns([
                pl.when(pl.col('taxonomy').str.contains('Anelloviridae')).then(pl.lit('Cardeaviricetes'))
                    .when(~pl.col('taxonomy').str.contains('viricetes')).then(pl.lit('No class'))
                    .when(pl.col('taxonomy').str.contains('viricetes')).then(pl.col('taxonomy').str.split(';').list[4])	
                    .alias('Class')
            ])
    )

    # load normscore tsv
    normscore = (
        pl.read_csv(args.normscore_tsv, separator='\t', null_values=["NA"], has_header=False, new_columns=['seq_name', 'ref', 'normscore'])
            .with_columns([
                pl.col('ref').str.split('--').list[0].str.replace('_', ' ').alias('Species')
            ])
            .sort('normscore', descending=True)
            .unique(['seq_name'], maintain_order=True)
    )

    # load VMR
    msl = pl.read_excel(args.vmr_url, sheet_name='VMR MSL40', columns=['Species', 'Genus', 'Family', 'Order', 'Class'])

    # join normscore with VMR to get class labels
    ictv_class = (
        normscore
            .join(msl, on='Species', how='left')
    )

    # combine all results
    (
        classify
            .join(ictv_class, on=['seq_name', 'Class'], how='left')
            .write_csv(args.output, separator='\t')
    )


if __name__ == "__main__":
    sys.exit(main())
