#!/usr/bin/env python

"""Annotate REFERENCEACTIVITY sylphmpa rows with assembly activity via GANI RBHs."""

import argparse
import gzip
import re
import sys

import polars as pl

MVIRS_COUNTS = re.compile(r"OPRs=(\d+).*HSs=(\d+)", re.IGNORECASE)


def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Add tr, mvirs, and propagate columns to a sylphmpa profile using reciprocal-best GANI hits."
    )
    parser.add_argument("--sylph_tax", required=True, help="REFERENCEACTIVITY sylphmpa path.")
    parser.add_argument("--classify", required=True, help="CLASSIFY TSV (gzipped or plain).")
    parser.add_argument("--mvirs_fasta", required=True, help="mVIRs FASTA (gzipped or plain).")
    parser.add_argument("--propagate", required=True, help="PropagAtE TSV (gzipped or plain).")
    parser.add_argument("--gani", required=True, help="vClust new2all gANI TSV without header: query, reference, gani.")
    parser.add_argument("--uhvdb_metadata", required=True, help="UHVDB metadata TSV (gzipped or plain).")
    parser.add_argument("--output", required=True, help="Annotated sylphmpa path.")
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def _read_csv(path, **kwargs):
    kwargs.setdefault("null_values", ["NA", ""])
    try:
        df = pl.read_csv(path, **kwargs)
    except Exception:
        return None
    if df.height == 0:
        return None
    return df


def _open_text(path):
    if str(path).endswith(".gz"):
        return gzip.open(path, "rt", encoding="utf-8", errors="replace")
    return open(path, encoding="utf-8", errors="replace")


def parent_id(name):
    if name is None:
        return None
    token = str(name).split()[0]
    token = token.split("|", 1)[0]
    if ":" in token:
        left, right = token.rsplit(":", 1)
        if re.fullmatch(r"\d+-\d+", right or ""):
            token = left
    return token or None


def parent_expr(col):
    return (
        col.cast(pl.Utf8)
        .str.extract(r"^([^\s]+)", 1)
        .str.replace(r"\|.*$", "")
        .str.replace(r":\d+-\d+$", "")
    )


def read_sylphmpa(path):
    with _open_text(path) as fh:
        first = fh.readline()
    comment = first if first.startswith("#") else None
    skip = 1 if comment else 0
    df = _read_csv(path, separator="\t", skip_rows=skip, infer_schema_length=0)
    return comment, df


def write_sylphmpa(comment, df, output_path):
    cols = df.columns
    with open(output_path, "w", encoding="utf-8", newline="") as fh:
        if comment:
            fh.write(comment if comment.endswith("\n") else comment + "\n")
        fh.write("\t".join(cols) + "\n")
        for row in df.iter_rows():
            fh.write("\t".join("NA" if v is None or v == "" else str(v) for v in row) + "\n")


def load_species_map(path):
    uhvdb = _read_csv(path, separator="\t")
    if uhvdb is None or "uhvdb_id" not in uhvdb.columns or "species_cluster_id" not in uhvdb.columns:
        return pl.DataFrame(schema={"uhvdb_id": pl.Utf8, "species_cluster_id": pl.Int64})
    if "species_rep" in uhvdb.columns:
        uhvdb = uhvdb.filter(pl.col("uhvdb_id") == pl.col("species_rep"))
    elif "seq_name" in uhvdb.columns and "seqhash_rep" in uhvdb.columns:
        uhvdb = uhvdb.filter(pl.col("seq_name") == pl.col("seqhash_rep"))
    return (
        uhvdb.select(
            [
                pl.col("uhvdb_id").cast(pl.Utf8),
                pl.col("species_cluster_id").cast(pl.Int64, strict=False),
            ]
        )
        .filter(pl.col("uhvdb_id").is_not_null() & pl.col("species_cluster_id").is_not_null())
        .unique("uhvdb_id")
    )


def load_gani_pairs(path):
    raw = _read_csv(
        path,
        separator="\t",
        has_header=False,
        new_columns=["query", "reference", "gani"],
        schema_overrides={"query": pl.Utf8, "reference": pl.Utf8, "gani": pl.Float64},
    )
    if raw is None:
        return pl.DataFrame(schema={"virus": pl.Utf8, "uhvdb_id": pl.Utf8, "gani": pl.Float64})
    rows = []
    for query, reference, gani in raw.iter_rows():
        if query is None or reference is None or gani is None:
            continue
        query = str(query).split()[0]
        reference = str(reference).split()[0]
        q_uhvdb = query.startswith("UHVDB-")
        r_uhvdb = reference.startswith("UHVDB-")
        if q_uhvdb == r_uhvdb:
            continue
        if r_uhvdb:
            rows.append({"virus": query, "uhvdb_id": reference, "gani": float(gani)})
        else:
            rows.append({"virus": reference, "uhvdb_id": query, "gani": float(gani)})
    if not rows:
        return pl.DataFrame(schema={"virus": pl.Utf8, "uhvdb_id": pl.Utf8, "gani": pl.Float64})
    return (
        pl.DataFrame(rows)
        .group_by(["virus", "uhvdb_id"])
        .agg(pl.col("gani").max())
    )


def reciprocal_best_hits(pairs):
    if pairs is None or pairs.height == 0:
        return pl.DataFrame(schema={"virus": pl.Utf8, "uhvdb_id": pl.Utf8, "gani": pl.Float64})
    best_virus = (
        pairs.sort(["virus", "gani"], descending=[False, True])
        .unique("virus", keep="first")
        .rename({"uhvdb_id": "best_uhvdb", "gani": "virus_gani"})
    )
    best_uhvdb = (
        pairs.sort(["uhvdb_id", "gani"], descending=[False, True])
        .unique("uhvdb_id", keep="first")
        .rename({"virus": "best_virus", "gani": "uhvdb_gani"})
    )
    return (
        best_virus.join(best_uhvdb, left_on="best_uhvdb", right_on="uhvdb_id", how="inner")
        .filter(pl.col("virus") == pl.col("best_virus"))
        .select(
            [
                pl.col("virus"),
                pl.col("best_uhvdb").alias("uhvdb_id"),
                pl.col("virus_gani").alias("gani"),
            ]
        )
    )


def load_classify(path):
    raw = _read_csv(path, separator="\t")
    if raw is None or "seq_name" not in raw.columns:
        return pl.DataFrame(schema={"virus": pl.Utf8, "parent": pl.Utf8, "tr": pl.Utf8})
    topology = pl.col("topology").cast(pl.Utf8) if "topology" in raw.columns else pl.lit(None).cast(pl.Utf8)
    method = (
        pl.col("completeness_method").cast(pl.Utf8)
        if "completeness_method" in raw.columns
        else pl.lit(None).cast(pl.Utf8)
    )
    topology_up = topology.str.to_uppercase()
    method_up = method.str.to_uppercase()
    return raw.select(
        [
            pl.col("seq_name").cast(pl.Utf8).str.extract(r"^([^\s]+)", 1).alias("virus"),
            parent_expr(pl.col("seq_name")).alias("parent"),
            pl.when(topology_up.str.contains("ITR"))
            .then(pl.lit("ITR"))
            .when(topology_up.str.contains("DTR"))
            .then(pl.lit("DTR"))
            .when(method_up.str.contains("ITR"))
            .then(pl.lit("ITR"))
            .when(method_up.str.contains("DTR"))
            .then(pl.lit("DTR"))
            .otherwise(None)
            .alias("tr"),
        ]
    ).unique("virus", keep="first")


def load_mvirs(path):
    rows = []
    try:
        with _open_text(path) as fh:
            for line in fh:
                if not line.startswith(">"):
                    continue
                header = line[1:].strip()
                name = header.split()[0]
                parent = parent_id(name)
                match = MVIRS_COUNTS.search(header.replace("\t", " "))
                if parent is None or match is None:
                    continue
                oprs = int(match.group(1))
                hss = int(match.group(2))
                rows.append((parent, oprs, hss, oprs + hss))
    except (OSError, EOFError, gzip.BadGzipFile):
        rows = []
    if not rows:
        return pl.DataFrame(schema={"parent": pl.Utf8, "mvirs": pl.Utf8})
    return (
        pl.DataFrame(rows, schema=["parent", "oprs", "hss", "score"], orient="row")
        .sort(["parent", "score"], descending=[False, True])
        .unique("parent", keep="first")
        .select(
            [
                pl.col("parent"),
                (
                    pl.lit("OPRs=")
                    + pl.col("oprs").cast(pl.Utf8)
                    + pl.lit(";HSs=")
                    + pl.col("hss").cast(pl.Utf8)
                ).alias("mvirs"),
            ]
        )
    )


def load_propagate(path):
    raw = _read_csv(path, separator="\t")
    if raw is None or "prophage-host_ratio" not in raw.columns:
        return pl.DataFrame(schema={"virus": pl.Utf8, "parent": pl.Utf8, "propagate": pl.Float64})
    prophage = pl.col("prophage").cast(pl.Utf8) if "prophage" in raw.columns else pl.lit(None).cast(pl.Utf8)
    host = pl.col("host").cast(pl.Utf8) if "host" in raw.columns else pl.lit(None).cast(pl.Utf8)
    return raw.select(
        [
            prophage.str.extract(r"^([^\s]+)", 1).alias("virus"),
            parent_expr(host).alias("parent"),
            pl.col("prophage-host_ratio").cast(pl.Float64, strict=False).alias("propagate"),
        ]
    ).filter(pl.col("propagate").is_not_null())


def annotate_rbh(rbh, classify, mvirs, propagate):
    empty = pl.DataFrame(
        schema={
            "species_cluster_id": pl.Int64,
            "tr": pl.Utf8,
            "mvirs": pl.Utf8,
            "propagate": pl.Float64,
        }
    )
    if rbh is None or rbh.height == 0:
        return empty
    classified = classify if classify is not None and classify.height else pl.DataFrame(
        schema={"virus": pl.Utf8, "parent": pl.Utf8, "tr": pl.Utf8}
    )
    df = rbh.join(classified, on="virus", how="left")
    if mvirs is not None and mvirs.height:
        df = df.join(mvirs, on="parent", how="left")
    else:
        df = df.with_columns(pl.lit(None).cast(pl.Utf8).alias("mvirs"))
    if propagate is not None and propagate.height:
        by_virus = (
            propagate.filter(pl.col("virus").is_not_null())
            .sort(["virus", "propagate"], descending=[False, True])
            .unique("virus", keep="first")
            .select(["virus", pl.col("propagate").alias("propagate_virus")])
        )
        by_parent = (
            propagate.filter(pl.col("parent").is_not_null())
            .sort(["parent", "propagate"], descending=[False, True])
            .unique("parent", keep="first")
            .select(["parent", pl.col("propagate").alias("propagate_parent")])
        )
        df = df.join(by_virus, on="virus", how="left").join(by_parent, on="parent", how="left")
        df = df.with_columns(pl.coalesce(["propagate_virus", "propagate_parent"]).alias("propagate"))
    else:
        df = df.with_columns(pl.lit(None).cast(pl.Float64).alias("propagate"))
    return df.select(["species_cluster_id", "tr", "mvirs", "propagate"])


def main(args=None):
    args = parse_args(args)
    comment, sylph = read_sylphmpa(args.sylph_tax)
    if sylph is None:
        sylph = pl.DataFrame(schema={"clade_name": pl.Utf8})

    species_map = load_species_map(args.uhvdb_metadata)
    pairs = load_gani_pairs(args.gani)
    rbh = reciprocal_best_hits(pairs).join(species_map, on="uhvdb_id", how="inner")
    if rbh.height:
        rbh = (
            rbh.sort(["species_cluster_id", "gani"], descending=[False, True])
            .unique("species_cluster_id", keep="first")
        )

    annotations = annotate_rbh(
        rbh,
        load_classify(args.classify),
        load_mvirs(args.mvirs_fasta),
        load_propagate(args.propagate),
    )

    if "clade_name" not in sylph.columns:
        sylph = sylph.with_columns(pl.lit(None).cast(pl.Utf8).alias("clade_name"))
    sylph = sylph.with_columns(
        pl.col("clade_name")
        .cast(pl.Utf8)
        .str.extract(r"vSPECIES-(\d+)", 1)
        .cast(pl.Int64, strict=False)
        .alias("_species_cluster_id")
    )
    sylph = (
        sylph.join(annotations, left_on="_species_cluster_id", right_on="species_cluster_id", how="left")
        .drop("_species_cluster_id")
    )
    for col in ("tr", "mvirs", "propagate"):
        if col not in sylph.columns:
            sylph = sylph.with_columns(pl.lit(None).alias(col))

    write_sylphmpa(comment, sylph, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
