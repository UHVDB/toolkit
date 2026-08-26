#!/usr/bin/env python

"""Build uhvdb_metadata_sylphtax.tsv.gz from updated UHVDB metadata.

Output format (no header), one row per species representative:
  uhvdb_id <tab> virus_lineage <tab> host_lineage

virus_lineage = genomad ranks through class + empty order +
  vFAM-{family};vSUBFAM-{subfamily};vGENUS-{genus};vSUBGENUS-{subgenus};vSPECIES-{species}
host_lineage = final_host_lineage
"""

import argparse
import gzip
import sys

import polars as pl


def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Build sylph-tax metadata table from UHVDB metadata.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--metadata-tsv",
        required=True,
        help="Updated uhvdb_metadata.tsv or .tsv.gz",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output uhvdb_metadata_sylphtax.tsv.gz (headerless).",
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def _virus_lineage(genomad, family, subfamily, genus, subgenus, species):
    ranks = [part for part in str(genomad or "").split(";")][:5]
    while len(ranks) < 5:
        ranks.append("")
    prefix = ";".join(ranks)
    return (
        f"{prefix};;"
        f"vFAM-{family};vSUBFAM-{subfamily};"
        f"vGENUS-{genus};vSUBGENUS-{subgenus};vSPECIES-{species}"
    )


def build_sylphtax(metadata_path):
    df = pl.read_csv(metadata_path, separator="\t", null_values=["NA", ""])
    required = [
        "uhvdb_id",
        "species_rep",
        "genomad_taxonomy",
        "family_cluster_id",
        "subfamily_cluster_id",
        "genus_cluster_id",
        "subgenus_cluster_id",
        "species_cluster_id",
        "final_host_lineage",
    ]
    missing = [col for col in required if col not in df.columns]
    if missing:
        raise ValueError(f"Metadata is missing required columns: {missing}")

    species_reps = (
        df
        .filter(pl.col("uhvdb_id") == pl.col("species_rep"))
        .unique("uhvdb_id", keep="first")
        .with_columns([
            pl.col("family_cluster_id").cast(pl.String).fill_null(""),
            pl.col("subfamily_cluster_id").cast(pl.String).fill_null(""),
            pl.col("genus_cluster_id").cast(pl.String).fill_null(""),
            pl.col("subgenus_cluster_id").cast(pl.String).fill_null(""),
            pl.col("species_cluster_id").cast(pl.String).fill_null(""),
            pl.col("genomad_taxonomy").fill_null(""),
            pl.col("final_host_lineage").fill_null(""),
        ])
    )

    rows = []
    for row in species_reps.iter_rows(named=True):
        rows.append({
            "uhvdb_id": row["uhvdb_id"],
            "virus_lineage": _virus_lineage(
                row["genomad_taxonomy"],
                row["family_cluster_id"],
                row["subfamily_cluster_id"],
                row["genus_cluster_id"],
                row["subgenus_cluster_id"],
                row["species_cluster_id"],
            ),
            "host_lineage": row["final_host_lineage"],
        })
    return pl.DataFrame(rows).sort("uhvdb_id")


def main(args=None):
    args = parse_args(args)
    out = build_sylphtax(args.metadata_tsv)
    with gzip.open(args.output, "wt") as handle:
        for row in out.iter_rows():
            handle.write("\t".join(str(col) for col in row) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
