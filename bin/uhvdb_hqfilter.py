#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Identify UHVDB complete genomes to update CheckV's database."
    epilog = "Example usage: python uhvdb_hqfilter.py --help"

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
        "-f",
        "--fasta",
        help="Path to FASTA file containing input genomes.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output FASTA file containing HQ genomes.",
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


    # identify HQ genomes
    hq_seqs = set(
        completeness
            .filter(
                (pl.col('aai_completeness') >= 90) |
                (pl.col('contig_id').is_in(dtr_seqs))
            )
            ['contig_id']
    )

    # write output FASTA file
    if args.fasta.endswith('.gz'):
        read_function = gzip.open
    else:
        read_function = open

    hq_seqs_lst = []
    with read_function(args.fasta, 'rt') as fasta_gunzipped:
        for record in SeqIO.parse(fasta_gunzipped, "fasta"):
            if record.id in hq_seqs:
                hq_seqs_lst.append(record)
    SeqIO.write(hq_seqs_lst, args.output, "fasta")

if __name__ == "__main__":
    sys.exit(main())
