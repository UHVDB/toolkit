#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Identify novel, unique protein hashes."
    epilog = "Example usage: python uhvdb_protein_hash.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input_prothash_tsv",
        help="Path to TSV file containing new protein hashes.",
    )
    parser.add_argument(
        "-u",
        "--input_uhvdb_prothash_tsv",
        help="Path to existing UHVDB protein hash TSV file."
    )
    parser.add_argument(
        "-o",
        "--output_combined_prothash_tsv",
        help="Path to output combined TSV file.",
    )
    parser.add_argument(
        "-n",
        "--output_new_unique_fna",
        help="Path to output new, unique proteins in fasta format.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    if args.input_uhvdb_prothash_tsv != '':
        # load UHVDB protein hashes (if provided)
        uhvdb_prothash_df = pl.read_csv(args.input_uhvdb_prothash_tsv, separator='\t')
        uhvdb_hashes = set(
            uhvdb_prothash_df["hash"]
        )
    else:
        uhvdb_hashes = set()
        uhvdb_prothash_df = pl.DataFrame({
            "protein_id": pl.Series([], dtype=pl.Utf8),
            "hash": pl.Series([], dtype=pl.Utf8)
        })

    # Load new hashes
    new_prothash_df = pl.read_csv(args.input_prothash_tsv, separator='\t', has_header=False, columns=['column_1', 'column_3']).rename({"column_1": "protein_id", "column_3": "hash"})

    # write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    combined_prothash_df = pl.concat([uhvdb_prothash_df, new_prothash_df], how='vertical').sort('protein_id')
    combined_prothash_df.write_csv(args.output_combined_prothash_tsv, separator='\t')
    # identify sequences associated with new unique hashes
    new_unique = set(
        new_prothash_df
            .filter(~pl.col("hash").is_in(uhvdb_hashes))
            .unique('hash')
            ["protein_id"]
    )

    # write out new unique sequences in fasta format
    with gzip.open(args.input_prothash_tsv, 'rt') as in_tsv:
        with open(args.output_new_unique_fna, 'w') as out_fna:
            for line in in_tsv:
                protein_id, sequence, hash = line.strip().split('\t')
                if protein_id in new_unique:
                    out_fna.write(f">{hash}\n")
                    out_fna.write(f"{sequence}\n")

if __name__ == "__main__":
    sys.exit(main())
