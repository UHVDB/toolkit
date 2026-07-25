#!/usr/bin/env python

import argparse
import gzip
import sys

import polars as pl
from Bio import SeqIO


def parse_args(args=None):
    description = "Identify confident genomes initially categorized as uncertain."
    epilog = "Example usage: python uhvdb_hcfilter.py --help"

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
        "-f",
        "--fasta",
        help="Path to FASTA file containing uncertain viruses.",
    )
    parser.add_argument(
        "-o",
        "--output_tsv",
        help="Output TSV file containing hmmsearch results.",
    )
    parser.add_argument(
        "--output_fasta",
        help="Output FASTA file containing new confident viruses.",
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
            if not line or line[0] == '#':
                continue
            strip_split = line.strip().split()
            if len(strip_split) < 5:
                continue
            protein = strip_split[0]
            genome = protein.rsplit('_', 1)[0]
            target = strip_split[2]
            results.append({'contig_id': genome, 'protein': protein, 'hallmark': target, 'evalue': float(strip_split[4])})

    ### summarize hallmarks per uncertain genome
    if results:
        uncertain2_confident = (
            pl.DataFrame(results)
                .with_columns([
                    pl.when(pl.col('hallmark').is_in(genomad_virus_hallmarks)).then(1).otherwise(0).alias('virus_hallmarks'),
                    pl.when(pl.col('hallmark').is_in(genomad_plasmid_hallmarks)).then(1).otherwise(0).alias('plasmid_hallmarks'),
                ])
                .sort('evalue', descending=False)
                .group_by('protein')
                .first()
                .group_by(['contig_id'])
                .agg([pl.col('virus_hallmarks').sum().alias('virus_hallmarks'), pl.col('plasmid_hallmarks').sum().alias('plasmid_hallmarks')])
        )
    else:
        uncertain2_confident = pl.DataFrame(
            schema={
                'contig_id': pl.Utf8,
                'virus_hallmarks': pl.Int64,
                'plasmid_hallmarks': pl.Int64,
            }
        )

    uncertain2_confident.write_csv(args.output_tsv, separator='\t', include_header=True)

    hc_seqs = set(
        uncertain2_confident
            .filter(
                (pl.col('virus_hallmarks') >= 3) &
                (pl.col('plasmid_hallmarks') == 0)
            )
            ['contig_id']
    ) if results else set()


    # write output FASTA file
    if args.fasta.endswith('.gz'):
        read_function = gzip.open
    else:
        read_function = open

    hq_seqs_lst = []
    with read_function(args.fasta, 'rt') as fasta_gunzipped:
        for record in SeqIO.parse(fasta_gunzipped, "fasta"):
            if record.id in hc_seqs:
                hq_seqs_lst.append(record)
    SeqIO.write(hq_seqs_lst, args.output_fasta, "fasta")

if __name__ == "__main__":
    sys.exit(main())
