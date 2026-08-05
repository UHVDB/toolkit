#!/usr/bin/env python

import argparse
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import polars as pl
import pysam

METRIC_COLUMNS = [
    "covered_bases",
    "gene_length",
    "breadth",
    "covered_bases_mincov",
    "breadth_mincov",
    "mean_depth",
]

COORD_COLUMNS = ["start", "end", "strand", "partial"]


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
        help="UHVDB protein annotations as .tsv.gz or .parquet "
        "(preferably parquet sorted/filterable by genomovar_rep).",
        required=True,
    )
    parser.add_argument(
        "-c",
        "--coords",
        help="Optional gzipped TSV with protein_id,start,end[,strand,partial]. "
        "Used when annotations lack start/end columns.",
        default=None,
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
    parser.add_argument(
        "-t",
        "--threads",
        help="Worker processes for per-contig BAM coverage (default: 1).",
        type=int,
        default=1,
    )
    parser.add_argument("--version", action="version", version="1.2.0")
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


def write_tsv(df, output_path):
    """Write TSV without polars write_csv/sink_csv (sysinfo cgroup panic on SLURM)."""
    cols = df.columns
    with open(output_path, "w", encoding="utf-8", newline="") as fh:
        fh.write("\t".join(cols) + "\n")
        for row in df.iter_rows():
            fh.write(
                "\t".join("" if v is None else str(v) for v in row) + "\n"
            )


def write_empty(annotations_path, output_path):
    """Write header-only output with metric columns."""
    if annotations_path.endswith(".parquet"):
        header = pl.scan_parquet(annotations_path).head(0).collect()
    else:
        header = pl.read_csv(annotations_path, separator="\t", n_rows=0)
    for col in COORD_COLUMNS:
        if col not in header.columns:
            header = header.with_columns(pl.lit(None).alias(col))
    write_tsv(
        header.with_columns([pl.lit(None).alias(c) for c in METRIC_COLUMNS]),
        output_path,
    )


def scan_annotations(annotations_path):
    """Lazy-scan annotations from parquet or TSV/TSV.GZ."""
    if annotations_path.endswith(".parquet"):
        return pl.scan_parquet(annotations_path)
    return pl.scan_csv(annotations_path, separator="\t")


def attach_coords(annotations, coords_path):
    """Join start/end coordinates onto annotations when missing."""
    if {"start", "end"}.issubset(annotations.columns):
        return annotations

    if not coords_path:
        sys.exit(
            "ERROR: protein annotations lack start/end columns. "
            "Provide --coords with protein_id,start,end, or use the UHVDB 5.0 "
            "annotations file that already includes coordinates."
        )

    protein_ids = annotations.get_column("protein_id").to_list()
    coords = (
        pl.scan_csv(coords_path, separator="\t")
        .filter(pl.col("protein_id").is_in(protein_ids))
        .collect()
    )
    keep = [c for c in COORD_COLUMNS if c in coords.columns]
    if "start" not in keep or "end" not in keep:
        sys.exit(f"ERROR: coords file must contain start and end columns: {coords_path}")

    return annotations.join(coords.select(["protein_id", *keep]), on="protein_id", how="left")


def _contig_metrics(bam_path, contig_name, gene_rows, min_cov):
    """Compute coverage metrics for all genes on one contig."""
    metric_rows = []
    n_skipped = 0
    with pysam.AlignmentFile(bam_path, "rb") as bam:
        coverage = bam.count_coverage(contig_name)
        depth = np.asarray(coverage[0], dtype=np.int32)
        for base in coverage[1:]:
            depth += np.asarray(base, dtype=np.int32)

    for protein_id, start, end in gene_rows:
        if start is None or end is None:
            n_skipped += 1
            continue
        metrics = gene_coverage_metrics(depth, start, end, min_cov)
        metric_rows.append({"protein_id": protein_id, **metrics})
    return metric_rows, n_skipped


def main(args=None):
    args = parse_args(args)
    threads = max(1, int(args.threads))

    with pysam.AlignmentFile(args.bam, "rb") as bam:
        bam_refs = list(bam.references)

    if not bam_refs:
        write_empty(args.annotations, args.output)
        return

    bam_ref_set = set(bam_refs)
    annotations = (
        scan_annotations(args.annotations)
        .filter(pl.col("genomovar_rep").is_in(bam_refs))
        .collect()
    )

    if annotations.height == 0:
        write_empty(args.annotations, args.output)
        return

    annotations = attach_coords(annotations, args.coords)

    contig_jobs = []
    for group_key, genes in annotations.group_by("genomovar_rep"):
        contig_name = group_key[0]
        if contig_name not in bam_ref_set:
            continue
        gene_rows = list(
            zip(
                genes.get_column("protein_id").to_list(),
                genes.get_column("start").to_list(),
                genes.get_column("end").to_list(),
            )
        )
        contig_jobs.append((args.bam, contig_name, gene_rows, args.min_cov))

    metric_rows = []
    n_skipped = 0
    if threads == 1 or len(contig_jobs) <= 1:
        for job in contig_jobs:
            rows, skipped = _contig_metrics(*job)
            metric_rows.extend(rows)
            n_skipped += skipped
    else:
        workers = min(threads, len(contig_jobs))
        with ProcessPoolExecutor(max_workers=workers) as pool:
            futures = [pool.submit(_contig_metrics, *job) for job in contig_jobs]
            for fut in as_completed(futures):
                rows, skipped = fut.result()
                metric_rows.extend(rows)
                n_skipped += skipped

    if n_skipped:
        print(
            f"WARNING: skipped {n_skipped} annotation rows without start/end",
            file=sys.stderr,
        )

    metrics_df = pl.DataFrame(metric_rows) if metric_rows else pl.DataFrame(
        schema={"protein_id": pl.Utf8, **{c: pl.Float64 for c in METRIC_COLUMNS}}
    )
    result = annotations.join(metrics_df, on="protein_id", how="left")
    write_tsv(result, args.output)


if __name__ == "__main__":
    main()
