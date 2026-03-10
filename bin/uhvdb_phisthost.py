#!/usr/bin/env python

import argparse
import gzip
import re
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Parse phist output to identify host species."
    epilog = "Example usage: python uhvdb_phist.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--host_info",
        help="Path to TSV file linking host genome ID to taxonomy.",
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

    # load host info
    host_info = pl.read_csv(
        args.host_info, separator='\t'
    )

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
                genome_id = re.match(r'(^GC(A|F)_\d+\.\d+)(.*)', genome_id_1).group(1)
                for hit in split[1:-1]:
                    if ':' not in hit:
                        continue
                    # print(hit.split(':'))
                    index, perc_kmers = hit.split(':')
                    if float(perc_kmers) >= 0.2:
                        phist_lst.append({
                            'Target id': virus_dict[int(index)-1],
                            'Genome': genome_id,
                            'Containment': perc_kmers
                        })
                    else:
                        continue
            line_num += 1
            if line_num % 10000 == 0:
                print(f'Processed {line_num} lines')

    phist_hits = (
        pl.DataFrame(phist_lst)
            .join(host_info, on='Genome', how='inner')
    )
    phist_hits.write_csv(args.output + '.phist.tsv', separator='\t')

    phist_host = (
        phist_hits
            .group_by(['Target id', 'Repr_taxonomy'])
            .agg([pl.len().alias('connections')])
            .group_by('Target id')
            .agg([
                pl.col('connections').sum().alias('total_connections'),
                pl.col('connections').max().alias('max_connections'),
                pl.col("Repr_taxonomy").sort_by("connections", descending=True).first().alias('top_taxonomy')
            ])
            .with_columns([
                (pl.col('max_connections') / pl.col('total_connections')).alias('species_agreement'),
            ])
            .filter(pl.col('species_agreement') >= 0.7)
            
    )
    phist_host.write_csv(args.output + '.phisthost.tsv', separator='\t')

if __name__ == "__main__":
    sys.exit(main())
