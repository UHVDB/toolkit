#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Identify novel, unique sequences hashes."
    epilog = "Example usage: python uhvdb_unique_hash.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input_seqhash_tsv",
        help="Path to TSV file containing new sequence hashes.",
    )
    parser.add_argument(
        "-c",
        "--new_classify_tsv_gz",
        help="Path to TSV file containing new classify TSV.",
    )
    parser.add_argument(
        "-u",
        "--input_uhvdb_seqhash_tsv",
        help="Path to existing UHVDB sequence hash TSV file."
    )
    parser.add_argument(
        "-d∂",
        "--uhvdb_metadata_tsv_gz",
        help="Path to existing UHVDB metadata TSV file."
    )
    parser.add_argument(
        "-o",
        "--output_combined_seqhash_tsv",
        help="Path to output combined TSV file.",
    )
    parser.add_argument(
        "-n",
        "--output_new_unique_fna",
        help="Path to output new, unique sequences in fasta format.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    

    if args.input_uhvdb_seqhash_tsv != '':
        # load UHVDB sequence hashes (if provided)
        uhvdb_seqhash_in = pl.read_csv(args.input_uhvdb_seqhash_tsv, separator='\t')
        uhvdb_metadata_df = pl.read_csv(args.uhvdb_metadata_tsv_gz, separator='\t', columns=['original_name', 'completeness_method'])

        uhvdb_hashes = set(
            uhvdb_seqhash_in["hash"]
        )

        uhvdb_seqhash_df = uhvdb_seqhash_in.join(uhvdb_metadata_df, on='original_name', how='inner')
    else:
        uhvdb_hashes = set()
        uhvdb_seqhash_df = pl.DataFrame({
            "original_id": pl.Series([], dtype=pl.Utf8),
            "hash": pl.Series([], dtype=pl.Utf8),
            "completeness_method":  pl.Series([], dtype=pl.Utf8),
        })    

    # Load new hashes
    new_seqhash_in = pl.read_csv(args.input_seqhash_tsv, separator='\t', has_header=False, columns=['column_1', 'column_2']).rename({"column_1": "original_id", "column_2": "hash"})
    new_classify_df = pl.read_csv(args.new_classify_tsv_gz, separator='\t', columns=['seq_name', 'completeness_method']).rename({'seq_name': 'original_id'})
    new_seqhash_df = new_seqhash_in.join(new_classify_df, on='original_id', how='inner')

    # write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    combined_seqhash_df = pl.concat([uhvdb_seqhash_df, new_seqhash_df], how='vertical')
    combined_seqhash_df.write_csv(args.output_combined_seqhash_tsv, separator='\t')

    combined_seqhash_df2 = (
        combined_seqhash_df
            .with_columns([
                pl.when(pl.col('completeness_method').str.contains('DTR'))
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('dtr_score')
            ])
            .sort(pl.col('dtr_score'), descending=True)
    )

    # identify sequences associated with new unique hashes
    new_unique = set(
        new_seqhash_df
            .filter(~pl.col("hash").is_in(uhvdb_hashes))
            .unique('hash')
            ["original_id"]
    )

    # write out new unique sequences in fasta format
    with gzip.open(args.input_seqhash_tsv, 'rt') as in_tsv:
        with open(args.output_new_unique_fna, 'w') as out_fna:
            for line in in_tsv:
                original_id, hash, sequence = line.strip().split('\t')
                if original_id in new_unique:
                    out_fna.write(f">{original_id}\n")
                    out_fna.write(f"{sequence}\n")

if __name__ == "__main__":
    sys.exit(main())
