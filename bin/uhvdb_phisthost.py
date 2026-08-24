#!/usr/bin/env python

import argparse
import glob
import sys

import polars as pl


def _empty_metadata_df():
    return pl.DataFrame({
        'genome_id': pl.Series([], dtype=pl.String),
        'taxonomy': pl.Series([], dtype=pl.String),
        'cluster': pl.Series([], dtype=pl.String),
    })


def _empty_phist_input_df():
    return pl.DataFrame({
        'Target id': pl.Series([], dtype=pl.String),
        'Genome': pl.Series([], dtype=pl.String),
        'Containment': pl.Series([], dtype=pl.Float64),
    })


def _empty_phisthost_df():
    return pl.DataFrame({
        'uhvdb_id': pl.Series([], dtype=pl.String),
        'total_connections': pl.Series([], dtype=pl.UInt32),
        'rank': pl.Series([], dtype=pl.String),
        'agreement': pl.Series([], dtype=pl.Float64),
        'consensus_taxonomy': pl.Series([], dtype=pl.String),
    })


def _extract_rank_token(taxonomy, rank):
    if taxonomy is None:
        return None
    for token in str(taxonomy).split(';'):
        token = token.strip()
        if token.startswith(f'{rank}__'):
            value = token.split('__', 1)[1].strip()
            if value:
                return token
            return None
    return None


def _species_genus_family_consensus(taxonomy_list, min_agreement=0.7):
    """Return all passing consensus hits across species, genus, and family."""
    taxonomies = [t for t in taxonomy_list if t is not None and str(t).strip()]
    total = len(taxonomies)
    if total == 0:
        return []

    rank_full = {
        's': 'species',
        'g': 'genus',
        'f': 'family',
    }

    results = []
    for rank in ['s', 'g', 'f']:
        counts = {}
        for taxonomy in taxonomies:
            token = _extract_rank_token(taxonomy, rank)
            if token is None:
                continue
            counts[token] = counts.get(token, 0) + 1

        if not counts:
            continue

        top_token, top_count = max(counts.items(), key=lambda x: x[1])
        agreement = top_count / total
        if agreement >= min_agreement:
            results.append({
                'rank': rank_full[rank],
                'agreement': agreement,
                'consensus_taxonomy': top_token,
            })

    return results


def parse_args(args=None):
    description = "Parse phist output to identify host species."
    epilog = "Example usage: python uhvdb_phist.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-u",
        "--uhbdb_dir",
        help="Path to UHVDB directory containing host information.",
    )
    parser.add_argument(
        "-t",
        "--phist_csv",
        help="Path to TSV file output by phist.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing host taxonomy prediction.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    meta_df_lst = []
    for file in glob.glob(args.uhbdb_dir + "/*/*/*.metadata.tsv.gz"):
        # load host info
        try:
            df = pl.read_csv(file, separator='\t')
        except pl.exceptions.NoDataError:
            continue

        if len(df.columns) == 15:
            df = df.with_columns([
                pl.col('genome_id').alias('cluster')
            ])
        meta_df_lst.append(df)

    if meta_df_lst:
        metadata = pl.concat(meta_df_lst, how='diagonal_relaxed')
        if 'genome_id' not in metadata.columns:
            metadata = metadata.with_columns(pl.lit(None).cast(pl.String).alias('genome_id'))
        if 'taxonomy' not in metadata.columns:
            metadata = metadata.with_columns(pl.lit(None).cast(pl.String).alias('taxonomy'))
    else:
        metadata = _empty_metadata_df()

    # load phist output
    virus_dict = {}
    phist_lst = []

    line_num = 0
    with open(args.phist_csv, 'r') as f_in:
        for line in f_in:
            if line.startswith('kmer-length'):
                split = line.strip().split(',')[1:]
                for index, virus in enumerate(split):
                    virus_dict[index] = virus
            elif line.startswith('query-samples'):
                continue
            else:
                split = line.strip().split(',')
                genome_id_1 = split[0]
                genome_id = genome_id_1.split('.f')[0]
                for hit in split[1:-1]:
                    if ':' not in hit:
                        continue
                    # print(hit.split(':'))
                    index, perc_kmers = hit.split(':')
                    perc_kmers = float(perc_kmers)
                    if perc_kmers >= 0.2:
                        phist_lst.append({
                            'Target id': virus_dict[int(index)-1],
                            'Genome': genome_id,
                            'Containment': perc_kmers
                        })
                    else:
                        continue
            line_num += 1
            if line_num % 1000000 == 0:
                print(f'Processed {line_num} lines')

    phist_input_df = pl.DataFrame(phist_lst) if phist_lst else _empty_phist_input_df()

    phist_hits = (
        phist_input_df
            .join(metadata, left_on='Genome', right_on='genome_id', how='inner')
            .rename({'Target id': 'uhvdb_id'})
    )
    phist_hits.write_csv(args.output + '_phist.tsv', separator='\t')

    if phist_hits.height == 0 or 'taxonomy' not in phist_hits.columns:
        _empty_phisthost_df().write_csv(args.output + '_phisthost.tsv', separator='\t')
        return 0

    phist_host = (
        phist_hits
            .group_by('uhvdb_id')
            .agg([
                pl.len().alias('total_connections'),
                pl.col('taxonomy').alias('taxonomy_hits'),
            ])
            .with_columns([
                pl.col('taxonomy_hits').map_elements(
                    lambda values: _species_genus_family_consensus(values, min_agreement=0.7),
                    return_dtype=pl.List(
                        pl.Struct([
                            pl.Field('rank', pl.String),
                            pl.Field('agreement', pl.Float64),
                            pl.Field('consensus_taxonomy', pl.String),
                        ])
                    )
                ).alias('consensus')
            ])
            .explode('consensus')
            .unnest('consensus')
            .drop('taxonomy_hits')

    )
    phist_host.write_csv(args.output + '_phisthost.tsv', separator='\t')
    return 0

if __name__ == "__main__":
    sys.exit(main())
