#!/usr/bin/env python

import argparse
import gzip
import sys

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
        "-u",
        "--uhvdb_metadata_tsv",
        help="Path to existing UHVDB metadata TSV file."
    )
    parser.add_argument(
        "-o",
        "--output_tsv",
        help="Path to output combined TSV file.",
    )
    parser.add_argument(
        "-n",
        "--output_fna",
        help="Path to output new, unique sequences in fasta format.",
    )
    parser.add_argument(
        "-m",
        "--output_id_map_tsv",
        help="Path to output TSV linking original_id to uhvdb_id.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # load UHVDB metadata
    uhvdb_seqhash_df = (
        pl.read_csv(args.uhvdb_metadata_tsv, separator='\t', columns=['seq_name', 'uhvdb_id', 'hash'])
        .rename({"seq_name": "original_id"})
    )

    uhvdb_hashes = set(
        uhvdb_seqhash_df["hash"]
    )

    # Load new hashes
    new_seqhash_df = (
        pl.read_csv(args.input_seqhash_tsv, separator='\t', has_header=False, columns=['column_1', 'column_2'])
            .rename({"column_1": "original_id", "column_2": "hash"})
    )
    
    # write out combined tsv with original_id and hash for all sequences (including those already in UHVDB)
    combined_seqhash_df = pl.concat([uhvdb_seqhash_df[['original_id', 'hash']], new_seqhash_df], how='vertical')
    combined_seqhash_df.write_csv(args.output_tsv, separator='\t')

    # identify new sequences to output based only on whether the hash is novel
    # relative to existing UHVDB hashes
    novel_seqhash_df = (
        new_seqhash_df
            .filter(~pl.col('hash').is_in(uhvdb_hashes))
            .sort(['hash', 'original_id'])
            .unique(subset=['hash'], keep='first')
    )

    max_uhvdb_num = (
        uhvdb_seqhash_df['uhvdb_id']
            .str.extract(r'^UHVDB-(\d+)$', 1)
            .cast(pl.Int64, strict=False)
            .max()
    )
    next_uhvdb_num = int(max_uhvdb_num or 0) + 1

    novel_seqhash_df = novel_seqhash_df.with_columns(
        pl.format(
            'UHVDB-{}',
            pl.int_range(next_uhvdb_num, next_uhvdb_num + novel_seqhash_df.height),
        ).alias('uhvdb_id')
    )

    original_id_to_uhvdb_id = dict(
        zip(
            novel_seqhash_df['original_id'].to_list(),
            novel_seqhash_df['uhvdb_id'].to_list(),
            strict=True,
        )
    )

    hash_to_uhvdb_id = pl.concat(
        [
            uhvdb_seqhash_df.select(['hash', 'uhvdb_id']).unique(subset=['hash'], keep='first'),
            novel_seqhash_df.select(['hash', 'uhvdb_id']),
        ]
    )
    (
        new_seqhash_df
        .join(hash_to_uhvdb_id, on='hash', how='left')
        .select(['original_id', 'uhvdb_id'])
        .sort('original_id')
        .write_csv(args.output_id_map_tsv, separator='\t')
    )

    # write out selected sequences in fasta format using assigned UHVDB IDs
    with gzip.open(args.input_seqhash_tsv, 'rt') as in_tsv:
        with open(args.output_fna, 'w') as out_fna:
            for line in in_tsv:
                original_id, hash, sequence = line.strip().split('\t')
                uhvdb_id = original_id_to_uhvdb_id.get(original_id)
                if uhvdb_id is not None:
                    out_fna.write(f">{uhvdb_id}\n")
                    out_fna.write(f"{sequence}\n")

if __name__ == "__main__":
    sys.exit(main())
