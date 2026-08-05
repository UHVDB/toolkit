#!/usr/bin/env python

import argparse
import gzip
import sys

import fastexcel
import polars as pl


def parse_args(args=None):
    description = "Compile UHVDB taxonomy data."
    epilog = "Example usage: python uhvdb_taxonomy.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-t",
        "--classify_tsv",
        help="Path to TSV file output by UHVDB's classify subworkflow.",
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
        pl.read_csv(args.classify_tsv, separator='\t', null_values=["NA"], columns=['uhvdb_id', 'taxonomy'])
            .with_columns([
                pl.when(pl.col('taxonomy').str.contains('Anelloviridae')).then(pl.lit('Cardeaviricetes'))
                    .when(~pl.col('taxonomy').str.contains('viricetes')).then(pl.lit('No class'))
                    .when(pl.col('taxonomy').str.contains('viricetes')).then(pl.col('taxonomy').str.split(';').list.get(4, null_on_oob=True))
                    .alias('Class')
            ])
    )

    # load normscore tsv
    normscore = (
        pl.read_csv(args.normscore_tsv, separator='\t', null_values=["NA"], has_header=False, new_columns=['uhvdb_id', 'ref', 'normscore'])
            .with_columns([
                pl.col('ref').str.split('--').list[0].str.replace('_', ' ').alias('Species')
            ])
            .sort('normscore', descending=True)
            .unique(['uhvdb_id'], maintain_order=True)
    )

    # load VMR (prefer sheet names starting with VMR, matching ictv_downloader.py)
    sheet_names = fastexcel.read_excel(args.vmr_url).sheet_names
    vmr_sheets = [s for s in sheet_names if s.upper().startswith('VMR')]
    if vmr_sheets:
        sheet_name = vmr_sheets[0]
    else:
        sheet_name = sheet_names[1] if len(sheet_names) > 1 else sheet_names[0]

    msl = pl.read_excel(
        args.vmr_url,
        sheet_name=sheet_name,
        columns=['Species', 'Genus', 'Family', 'Order', 'Class'],
    )

    # join normscore with VMR to get class labels
    ictv_class = (
        normscore
            .join(msl, on='Species', how='left')
    )

    # combine all results
    (
        classify
            .join(ictv_class, on=['uhvdb_id', 'Class'], how='left')
            .write_csv(args.output, separator='\t')
    )


if __name__ == "__main__":
    sys.exit(main())
