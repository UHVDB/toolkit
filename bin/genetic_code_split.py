#!/usr/bin/env python

import argparse
import polars as pl

def parse_args(args=None):
    description = "Split geNomad or genetic code TSV into multiple files using the same genetic code."
    epilog = "Example usage: python genetic_code_split.py --help"

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
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)

def main(args=None):
    args = parse_args(args)

    df = pl.read_csv(args.input, separator="\t", null_values=['NA'])

    for g_code in df["genetic_code"].unique().to_list():
        df_code = df.filter(pl.col("genetic_code") == g_code)
        output_path = f"{args.output}_gcode{g_code}.tsv"
        df_code[['seq_name']].write_csv(output_path, separator="\t")
        print(f"Wrote {output_path} with {df_code.height} records.")

if __name__ == "__main__":
    main()
