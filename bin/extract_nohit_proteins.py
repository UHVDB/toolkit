#!/usr/bin/env python

import argparse
import gzip

from Bio import SeqIO
import pandas as pd

def parse_args(args=None):
    description = "Identify and extract proteins without a UniProt hit."
    epilog = "Example usage: python extract_nohit_proteins.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input_tsv",
        help="Path to input TSV file produced by Bakta.",
    )
    parser.add_argument(
        "-f",
        "--input_faa",
        help="Path to input hypotheticals FAA file produced by Bakta.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Name for output FAA files.",
    )
    parser.add_argument(
        "-n",
        "--name_column",
        help="Column containing sequence names.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)



def main(args=None):
    args = parse_args(args)

    # load Bakta TSV
    df = pd.read_csv(args.input_tsv, sep='\t', skiprows=5)

    # identify proteins without UniProt hits
    nohit_set = set(df[
        (
            (df['Accession'].isnull()) | 
            (
                (~df['Accession'].astype(str).str.contains('UniParc')) &
                (~df['Accession'].astype(str).str.contains('UniRef')) &
                (~df['Accession'].astype(str).str.contains('UserProtein'))
            )
        )
    ][args.name_column])

    print(f"Identified {len(nohit_set)} no-hit proteins.")
    
    # extract no-hit proteins from FAA
    nohit_records = []
    with gzip.open(args.input_faa, 'rt') as f:
        for record in SeqIO.parse(f, 'fasta'):
            if record.id in nohit_set:
                nohit_records.append(record)

    SeqIO.write(nohit_records, args.output, 'fasta')
if __name__ == "__main__":
    main()
