#!/usr/bin/env python

import argparse

import numpy as np
import polars as pl
import pysam

pl.Config.set_streaming_chunk_size(10_000)

METRIC_COLUMNS = [
    "covered_bases",
    "gene_length",
    "breadth",
    "covered_bases_mincov",
    "breadth_mincov",
    "mean_depth",
]


def parse_args(args=None):
    description = """
        Compute per-gene coverage metrics from a BAM file and UHVDB protein annotations
        with start/end coordinates.
    """
    epilog = "Example usage: python uhvdb_genecoverage.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-b",
        "--bam",
        help="Path to BAM file with reference genomes as contigs.",
        required=True,
    )
    parser.add_argument(
        "-a",
        "--annotations",
        help="Path to gzipped UHVDB protein annotations TSV with start/end coordinates.",
        required=True,
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV path (uncompressed).",
        required=True,
    )
    parser.add_argument(
        "--min-cov",
        help="Minimum depth for covered_bases_mincov / breadth_mincov (default: 5).",
        type=int,
        default=5,
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def gene_coverage_metrics(depth, start, end, min_cov):
    """Compute coverage metrics for a 1-based inclusive gene interval."""
    gene_length = int(end) - int(start) + 1
    if gene_length <= 0:
        return {
            "covered_bases": 0,
            "gene_length": gene_length,
            "breadth": 0.0,
            "covered_bases_mincov": 0,
            "breadth_mincov": 0.0,
            "mean_depth": 0.0,
        }

    slice_ = depth[int(start) - 1 : int(end)]
    covered_bases = int(np.count_nonzero(slice_ >= 1))
    covered_bases_mincov = int(np.count_nonzero(slice_ >= min_cov))
    mean_depth = float(slice_.mean()) if slice_.size else 0.0

    return {
        "covered_bases": covered_bases,
        "gene_length": gene_length,
        "breadth": covered_bases / gene_length,
        "covered_bases_mincov": covered_bases_mincov,
        "breadth_mincov": covered_bases_mincov / gene_length,
        "mean_depth": mean_depth,
    }


def write_empty(annotations_path, output_path):
    """Write header-only output with metric columns."""
    header = pl.read_csv(annotations_path, separator="\t", n_rows=0)
    header.with_columns([pl.lit(None).alias(c) for c in METRIC_COLUMNS]).write_csv(
        output_path, separator="\t"
    )


def main(args=None):
    args = parse_args(args)

    with pysam.AlignmentFile(args.bam, "rb") as bam:
        bam_refs = set(bam.references)

        if not bam_refs:
            write_empty(args.annotations, args.output)
            return

        annotations = (
            pl.scan_csv(args.annotations, separator="\t")
            .filter(pl.col("genomovar_rep").is_in(list(bam_refs)))
            .collect()
        )

        if annotations.height == 0:
            write_empty(args.annotations, args.output)
            return

        metric_rows = []
        for group_key, genes in annotations.group_by("genomovar_rep"):
            contig_name = group_key[0]
            if contig_name not in bam_refs:
                continue

            coverage = bam.count_coverage(contig_name)
            depth = np.asarray(coverage[0], dtype=np.int32)
            for base in coverage[1:]:
                depth += np.asarray(base, dtype=np.int32)

            for row in genes.iter_rows(named=True):
                metrics = gene_coverage_metrics(
                    depth, row["start"], row["end"], args.min_cov
                )
                metric_rows.append({"protein_id": row["protein_id"], **metrics})

        metrics_df = pl.DataFrame(metric_rows)
        result = annotations.join(metrics_df, on="protein_id", how="left")
        result.write_csv(args.output, separator="\t")


if __name__ == "__main__":
    main()
