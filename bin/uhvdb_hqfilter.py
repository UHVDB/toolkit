#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Identify UHVDB complete genomes to update CheckV's database."
    epilog = "Example usage: python uhvdb_complete_genomes.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input_completeness",
        help="Path to TSV file output by CheckV completeness 2.",
    )
    parser.add_argument(
        "-c",
        "--classify_tsv",
        help="Path to TSV file containing UHVDB's classify output.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing medium/high-quality complete genomes.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    dtr_seqs = set(
        pl.read_csv(args.classify_tsv, separator='\t', columns=['seq_name', 'completeness', 'completeness_method'])
            .filter((pl.col('completeness') >= 80) & (pl.col('completeness_method').str.contains('DTR')))
            ['seq_name']
    )

    # load files
    completeness = pl.read_csv(
        args.input_completeness, separator='\t',
        columns=[
            "contig_id", "aai_completeness"
        ],
        null_values=["NA"]
    )


    # identify high/medium quality DTRs
    (
        completeness
            .filter(
                (pl.col('aai_completeness') >= 90) |
                (pl.col('contig_id').is_in(dtr_seqs))
            )
            [['contig_id']]
            .write_csv(args.output, separator='\t', include_header=False)
    )

if __name__ == "__main__":
    sys.exit(main())
