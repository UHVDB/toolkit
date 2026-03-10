#!/usr/bin/env python

import argparse
import polars as pl

def parse_args(args=None):
    description = "Split geNomad TSV into multiple files by taxa."
    epilog = "Example usage: python taxa_split.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to input TSV file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Prefix for output TSV files.",
    )
    parser.add_argument(
        "-r",
        "--rank",
        help="Taxonomic rank to split by.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)

def main(args=None):
    args = parse_args(args)

    df = (
        pl.read_csv(args.input, separator="\t", null_values=['NA'])
            .with_columns([
                pl.col('taxonomy').str.replace_all("Viruses;;;;;;Anelloviridae", 'Viruses;Monodnavira;Shotukuvirae;Commensaviricota;Cardeaviricetes;Sanitavirales;Anelloviridae'),
            ])
            .with_columns([
                pl.col('taxonomy').str.replace_all("Viruses;;;;;;", "Unclassified")
            ])
            .filter((pl.col('taxonomy').is_not_null()) & (pl.col('taxonomy') != "Unclassified"))
            .with_columns([
                pl.col('taxonomy').str.split(';').list[0].alias('Root'),
                pl.col('taxonomy').str.split(';').list[1].alias('Realm'),
                pl.col('taxonomy').str.split(';').list[2].alias('Kingdom'),
                pl.col('taxonomy').str.split(';').list[3].alias('Phylum'),
                pl.col('taxonomy').str.split(';').list[4].alias('Class'),
                pl.col('taxonomy').str.split(';').list[5].alias('Order'),
                pl.col('taxonomy').str.split(';').list[6].alias('Family')
            ])
    )

    for taxa in df[args.rank].unique().to_list():
        df_taxa = df.filter(pl.col(args.rank) == taxa)
        output_path = f"{args.output}_taxa{taxa}.tsv"
        df_taxa[['seq_name']].write_csv(output_path, separator="\t")
        print(f"Wrote {output_path} with {df_taxa.height} records.")

if __name__ == "__main__":
    main()
