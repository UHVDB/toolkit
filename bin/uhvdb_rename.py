#!/usr/bin/env python

import argparse
import sys

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
    classify = pl.read_csv(args.classify_tsv, separator='\t', null_values=["NA"])
    
    if "seq_name" not in classify.columns:
        classify = classify.rename({'contig_id': 'original_id'})
    else:
        classify = classify.rename({'seq_name': 'original_id'})

    # merge classify and id_mapping on original_id
    merged = classify.join(id_mapping, on="original_id", how="inner").drop("original_id")
    # drop original_id column and move uhvdb_id to the front
    merged = (
        merged
            .select(["uhvdb_id"] + [col for col in merged.columns if col != "uhvdb_id"])
    )
    # write to output file
    merged.write_csv(args.output_tsv, separator='\t', null_value="NA")

if __name__ == "__main__":
    sys.exit(main())
