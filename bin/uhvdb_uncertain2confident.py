#!/usr/bin/env python

import argparse
import gzip
import sys

import polars as pl


def parse_args(args=None):
    description = "Identify confident genomes initially categorized as uncertain."
    epilog = "Example usage: python uhvdb_uncertain2confident.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-b",
        "--hmmsearch_tbl",
        help="Path to TBL file output hmmmsearch.",
    )
    parser.add_argument(
        "-t",
        "--genomad_tsv",
        help="Path to TSV file containing geNomad marker metadata.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing hmmsearch results.",
    )
    parser.add_argument(
        "-i",
        "--ids",
        help="Output TXT file containing uncertain2confident genome IDs.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # identify hallmarks
    genomad_virus_hallmarks = set(
        pl.read_csv(args.genomad_tsv, separator='\t', ignore_errors=True)
        .filter(
            (pl.col('VIRUS_HALLMARK') == 1)
        )['MARKER']
    )

    genomad_plasmid_hallmarks = set(
        pl.read_csv(args.genomad_tsv, separator='\t', ignore_errors=True)
        .filter(
            (pl.col('PLASMID_HALLMARK') == 1)
        )['MARKER']
    )


    # parse hmmsearch results
    results = []
    with open(args.hmmsearch_tbl, 'r') as tbl:
        for line in tbl:
            if '#' in line[0]:
                continue
            strip_split = line.strip().split()
            protein = strip_split[0]
            genome = protein.rsplit('_', 1)[0]
            target = strip_split[2]
            results.append({'genome': genome, 'protein': protein, 'hallmark': target, 'evalue': float(strip_split[4])})
    tbl.close()

    ### summarize hallmarks per uncertain genome
    uncertain2_confident = (
        pl.DataFrame(results)
            .with_columns([
                pl.when(pl.col('hallmark').is_in(genomad_virus_hallmarks)).then(1).otherwise(0).alias('virus_hallmarks'),
                pl.when(pl.col('hallmark').is_in(genomad_plasmid_hallmarks)).then(1).otherwise(0).alias('plasmid_hallmarks'),
            ])
            .sort('evalue', descending=False)
            .group_by('protein')
            .first()
            .group_by(['genome'])
            .agg([pl.col('virus_hallmarks').sum().alias('virus_hallmarks'), pl.col('plasmid_hallmarks').sum().alias('plasmid_hallmarks')])
    )

    uncertain2_confident.write_csv(args.output, separator='\t', include_header=True)

    (
        uncertain2_confident
            .filter(
                (pl.col('virus_hallmarks') >= 3) &
                (pl.col('plasmid_hallmarks') == 0)
            )
            [['genome']]
            .write_csv(args.ids, separator='\t', include_header=False)
    )

if __name__ == "__main__":
    sys.exit(main())
