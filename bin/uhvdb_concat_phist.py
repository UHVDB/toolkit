#!/usr/bin/env python3
"""Concatenate PHIST hit tables (TSV/TSV.GZ/parquet) into uhvdb_phist.parquet."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import polars as pl

PHIST_COLS = [
    "uhvdb_id",
    "Genome",
    "Containment",
]


def parse_args(args=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("inputs", nargs="+", help="PHIST TSV, TSV.GZ, or parquet files.")
    parser.add_argument("-o", "--output", required=True, help="Output parquet path.")
    return parser.parse_args(args)


def load(path: Path) -> pl.LazyFrame:
    if path.suffix == ".parquet":
        lf = pl.scan_parquet(path)
    else:
        lf = pl.scan_csv(path, separator="\t", infer_schema_length=1000)
    names = lf.collect_schema().names()
    missing = [c for c in PHIST_COLS if c not in names]
    if missing:
        raise SystemExit(f"{path} missing columns: {missing}")
    return lf.select(PHIST_COLS).with_columns(
        pl.col("Containment").cast(pl.Float64)
    )


def main(args=None) -> int:
    args = parse_args(args)
    frames = [load(Path(p)) for p in args.inputs]
    pl.concat(frames, how="vertical_relaxed").sink_parquet(
        args.output, compression="zstd"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
