#!/usr/bin/env python

import argparse
import sys

import polars as pl


PHROG_COLS = ['cds_id', 'phrog', 'annot', 'category', 'protein_id', 'uhvdb_id']


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
        "-u",
        "--uhvdb_metadata",
        help="Path to TSV file containing UHVDB metadata.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing lifestyle information for each virus.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def _read_csv(path, **kwargs):
    """Read a CSV/TSV, returning None when the file is empty or unreadable."""
    kwargs.setdefault('null_values', ['NA'])
    try:
        df = pl.read_csv(path, **kwargs)
    except Exception:
        return None
    if df.height == 0:
        return None
    return df


def _empty_phrogs():
    return pl.DataFrame(schema={col: pl.Utf8 for col in PHROG_COLS})


def _empty_counts(name):
    return pl.DataFrame(schema={'uhvdb_id': pl.Utf8, name: pl.UInt32})


def _count_by_id(df, name):
    if df is None or df.height == 0:
        return _empty_counts(name)
    return (
        df
        .filter(pl.col('uhvdb_id').is_not_null())
        .group_by('uhvdb_id')
        .len()
        .rename({'len': name})
    )


def main(args=None):
    args = parse_args(args)

    # load classify tsv
    classify = pl.read_csv(
        args.classify_tsv, separator='\t', null_values=["NA"], columns=['uhvdb_id', 'topology', 'provirus']
    )

    # load bacphlip tsv (header is overwritten; first column is the sequence ID)
    bacphlip = pl.read_csv(
        args.bacphlip_tsv, separator='\t', null_values=["NA"], new_columns=['uhvdb_id', 'virulent', 'temperate']
    )

    # load protein2hash tsv (pharokka/phold/empathi IDs are protein hashes)
    protein2hash = (
        pl.read_csv(args.protein2hash_tsv, separator='\t')
            .rename({'hash': 'cds_id'})
            .with_columns([pl.col('protein_id').str.replace(r"_[^_]*$", "").alias('uhvdb_id')])
    )

    # load pharokka tsv
    pharokka_raw = _read_csv(
        args.pharokka_tsv, separator='\t', columns=['ID', 'phrog', 'annot', 'category']
    )
    if pharokka_raw is not None:
        pharokka = (
            pharokka_raw
                .rename({'ID': 'cds_id'})
                .join(protein2hash, on='cds_id', how='left')
                .select(PHROG_COLS)
        )
    else:
        pharokka = _empty_phrogs()

    # load phold tsv
    phold_raw = _read_csv(
        args.phold_tsv, separator='\t', columns=['cds_id', 'phrog', 'function', 'product']
    )
    if phold_raw is not None:
        phold = (
            phold_raw
                .rename({'product': 'annot', 'function': 'category'})
                .select(['cds_id', 'phrog', 'annot', 'category'])
                .join(protein2hash, on='cds_id', how='left')
                .select(PHROG_COLS)
        )
    else:
        phold = _empty_phrogs()

    # identify integrase/recombinases in pharokka and phold annotations
    phrogs = pl.concat([pharokka, phold])

    phrog_integrases = _count_by_id(
        phrogs.filter(pl.col('annot').fill_null('').str.contains(r'integrase|recombinase')),
        'phrog_integrases',
    )

    phrog_integration_excision = _count_by_id(
        phrogs.filter(pl.col('category').fill_null('').str.contains('integration and excision')),
        'phrog_integration_excision',
    )

    # load empathi csv (first column is an unnamed protein-hash index)
    empathi_raw = _read_csv(
        args.empathi_csv, columns=['', 'Annotation', 'integration']
    )
    if empathi_raw is None:
        empathi_raw = _read_csv(args.empathi_csv)
        if empathi_raw is not None and 'integration' in empathi_raw.columns:
            empathi_raw = (
                empathi_raw
                    .rename({empathi_raw.columns[0]: 'cds_id'})
                    .select(['cds_id', 'integration'])
            )
        else:
            empathi_raw = None
    else:
        empathi_raw = empathi_raw.rename({'': 'cds_id'})

    if empathi_raw is not None:
        empathi = (
            empathi_raw
                .with_columns(pl.col('integration').cast(pl.Float64))
                .filter(pl.col('integration') >= 0.9)
                .join(protein2hash, on='cds_id', how='left')
        )
        empathi = _count_by_id(empathi, 'empathi_integration')
    else:
        empathi = _empty_counts('empathi_integration')

    # include prior UHVDB viruses when metadata is provided (optional in the module)
    virus = classify
    if args.uhvdb_metadata:
        metadata = _read_csv(
            args.uhvdb_metadata, separator='\t', columns=['uhvdb_id', 'topology', 'provirus']
        )
        if metadata is not None:
            virus = (
                pl.concat([classify, metadata], how='vertical_relaxed')
                    .unique('uhvdb_id', keep='first')
            )

    # combine all results
    (
        virus
            .join(bacphlip, on='uhvdb_id', how='inner')
            .join(phrog_integrases, on='uhvdb_id', how='left')
            .join(phrog_integration_excision, on='uhvdb_id', how='left')
            .join(empathi, on='uhvdb_id', how='left')
            .write_csv(args.output, separator='\t')
    )


if __name__ == "__main__":
    sys.exit(main())
