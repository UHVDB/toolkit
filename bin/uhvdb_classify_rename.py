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
        "-c",
        "--classify_tsv",
        help="Path to TSV created by UHVDB/classify.",
    )
    parser.add_argument(
        "-i",
        "--id_mapping_tsv",
        help="Path to TSV file mapping original sequence IDs to new UHVDB IDs.",
    )
    parser.add_argument(
        "-o",
        "--output_tsv",
        help="Output TSV file containing classify.tsv with renamed sequences.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # load mapping file
    id_mapping = pl.read_csv(args.id_mapping_tsv, separator='\t', has_header=False, new_columns=["original_id", "uhvdb_id"])

    # load classify file
    classify = pl.read_csv(args.classify_tsv, separator='\t', null_values=["NA"]).rename({"seq_name":'original_id'})
    # merge classify and id_mapping on original_id
    merged = classify.join(id_mapping, on="original_id", how="inner")
    # replace seq_name with new_id
    merged = merged.rename({"uhvdb_id": "seq_name"})
    # write to output file
    merged.write_csv(args.output_tsv, separator='\t', null_value="NA")

if __name__ == "__main__":
    sys.exit(main())
