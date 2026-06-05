#!/usr/bin/env python

import argparse
import gzip
import sys

import polars as pl


def open_maybe_gzip(path: str, mode: str = "rt"):
    if path.endswith(".gz"):
        return gzip.open(path, mode)
    return open(path, mode)


def write_empty_output(path: str):
    with open_maybe_gzip(path, "wt"):
        pass


def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Filter a gANI graph to retain only edges where both IDs exist in the ID list."
    )
    parser.add_argument("--input_ids", required=True)
    parser.add_argument("--input_graph", required=True)
    parser.add_argument("--output_graph", required=True)
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def main(args=None):
    args = parse_args(args)

    ids_lf = (
        pl.scan_csv(
            args.input_ids,
            separator="\t",
            has_header=False,
            new_columns=["id"],
        )
        .select("id")
        .unique()
    )

    graph_lf = pl.scan_csv(
        args.input_graph,
        separator="\t",
        has_header=False,
        new_columns=["id1", "id2", "gani"],
    )

    filtered = (
        graph_lf
        .join(ids_lf, left_on="id1", right_on="id", how="semi")
        .join(ids_lf, left_on="id2", right_on="id", how="semi")
        .filter(pl.col("gani").is_not_null())
        .select(["id1", "id2", "gani"])
    )

    try:
        filtered.sink_csv(
            args.output_graph,
            separator="\t",
            include_header=False,
        )
    except pl.exceptions.NoDataError:
        write_empty_output(args.output_graph)

    return 0


if __name__ == "__main__":
    sys.exit(main())