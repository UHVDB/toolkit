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
        "-f",
        "--classify_fna",
        help="Path to nucleotide fasta created by UHVDB/classify.",
    )
    parser.add_argument(
        "-t",
        "--classify_tsv",
        help="Path to TSV file output UHVDB/classify.",
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

    # load files
    classify = pl.read_csv(
        args.classify_tsv, separator='\t',
        columns=[
            "seq_name", "completeness", "completeness_method", 'source_db'
        ],
        null_values=["NA"]
    )


    # identify high/medium quality DTRs
    (
        classify
            .filter(
                # identify medium/hq DTRs
                ( 
                    (pl.col('completeness_method').str.contains('DTR')) & (pl.col('completeness') >= 80)
                ) |
                # identify hq ncbi genomes
                (
                    (
                        (pl.col('source_db') == 'NCBI_VIRUS')) &
                        (pl.col('completeness') >= 90) &
                        (pl.col('completeness_method').is_in(["AAI (high-confidence)", "AAI (medium-confidence)"])
                    )
                )
            )
            [['seq_name']]
            .write_csv(args.output, separator='\t', include_header=False)
    )

if __name__ == "__main__":
    sys.exit(main())
