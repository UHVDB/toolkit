#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Compile UHVDB lifestyle data."
    epilog = "Example usage: python uhvdb_lifestyle.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-t",
        "--classify_tsv",
        help="Path to TSV file output UHVDB/classify.",
    )
    parser.add_argument(
        "-b",
        "--bacphlip_tsv",
        help="Path to TSV file output by bacphlip.",
    )
    parser.add_argument(
        "-p",
        "--pharokka_tsv",
        help="Path to TSV file output by Pharokka.",
    )
    parser.add_argument(
        "-l",
        "--phold_tsv",
        help="Path to TSV file output by PHOLD.",
    )
    parser.add_argument(
        "-e",
        "--empathi_csv",
        help="Path to CSV file output by Empathi.",
    )
    parser.add_argument(
        "-a",
        "--protein2hash_tsv",
        help="Path to TSV file output by protein2hash.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing lifestyle information for each virus.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    # load classify tsv
    classify = pl.read_csv(
        args.classify_tsv, separator='\t', null_values=["NA"], columns=['seq_name', 'topology', 'provirus']
    )

    # load bacphlip tsv
    bacphlip = pl.read_csv(
        args.bacphlip_tsv, separator='\t', null_values=["NA"], new_columns=['seq_name', 'virulent', 'temperate']
    )

    # load protein2hash tsv
    protein2hash = (
        pl.read_csv(args.protein2hash_tsv, separator='\t')
            .rename({'hash': 'cds_id'})
            .with_columns([pl.col('protein_id').str.replace(r"_[^_]*$", "").alias('seq_name')])
    )

    # load pharokka tsv
    pharokka = (
        pl.read_csv(args.pharokka_tsv, separator='\t', null_values=["NA"], columns=['ID', 'phrog', 'annot', 'category'])
            .rename({'ID':'cds_id'})
            .join(protein2hash, on='cds_id', how='left')
    )

    # load phold tsv
    phold = (
        pl.read_csv(args.phold_tsv, separator='\t', null_values=["NA"], columns=['cds_id', 'phrog', 'function', 'product'])
            .rename({'product':'annot', 'function':'category'})
            [['cds_id', 'phrog', 'annot', 'category']]
            .join(protein2hash, on='cds_id', how='left')
    )

    # identify integrase/recombinases in pharokka and phold annotations
    phrogs = (
        pl.concat([pharokka, phold])
    )

    phrog_integrases = (
        phrogs
            .filter(pl.col('annot').str.contains(r'integrase|recombinase'))
            .group_by('seq_name')
            .len()
            .rename({'len': 'phrog_integrases'})
    )

    phrog_integration_excision = (
        phrogs
            .filter(pl.col('category').str.contains('integration and excision'))
            .group_by('seq_name')
            .len()
            .rename({'len': 'phrog_integration_excision'})
    )

    # load empathi csv
    empathi = (
        pl.read_csv(args.empathi_csv, null_values=["NA"], columns=['', 'Annotation', 'integration'])
            .rename({'': 'cds_id'})
            .with_columns(pl.col('integration').cast(pl.Float64))
            .filter(pl.col('integration') >= 0.9)
            .join(protein2hash, on='cds_id', how='left')
            .group_by('seq_name')
            .len()
            .rename({'len': 'empathi_integration'})
    )

    # combine all results
    (
        classify
            .join(bacphlip, on='seq_name', how='inner')
            .join(phrog_integrases, on='seq_name', how='left')
            .join(phrog_integration_excision, on='seq_name', how='left')
            .join(empathi, on='seq_name', how='left')
            .write_csv(args.output, separator='\t')
    )


if __name__ == "__main__":
    sys.exit(main())
