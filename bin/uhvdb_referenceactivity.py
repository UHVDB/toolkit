#!/usr/bin/env python

"""Score Caudoviricetes detections with the figure_s15 inactive-virus classifier."""

import argparse
import math
import sys

import joblib
import numpy as np
import polars as pl


GENE_BREADTH_THRESHOLD = 0.8
META_HALLMARK_COLLISION_COLS = (
    "n_hallmarks",
    "mcp_hallmark",
    "terl_hallmark",
    "portal_hallmark",
)
OUTPUT_COLS = [
    "sample_id",
    "group",
    "species_cluster_id",
    "uhvdb_id",
    "ictv_class",
    "predicted_inactive_probability",
    "predicted_uninducible",
    "inactive_confidence_tier",
]
SYLPHMPA_COLUMN_RENAMES = {
    "ANI (if strain-level)": "ani",
    "Coverage (if strain-level)": "coverage",
    "Virus_host (if viral)": "virus_host",
    "lifestyle": "virus_lifestyle",
    "inactivity_probability": "uninducible_probability",
    "inactive_confidence_tier": "uninducible_tier",
}
SYLPHMPA_OUTPUT_COLS = [
    "clade_name",
    "relative_abundance",
    "sequence_abundance",
    "ani",
    "coverage",
    "virus_host",
    "virus_lifestyle",
    "pth_ratio",
    "uninducible_probability",
    "uninducible_tier",
]


def parse_args(args=None):
    description = "Assign inactive-virus scores to Caudoviricetes reference detections."
    epilog = "Example usage: python uhvdb_referenceactivity.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-m",
        "--uhvdb_metadata",
        required=True,
        help="Path to UHVDB metadata TSV (e.g. uhvdb_metadata.tsv.gz).",
    )
    parser.add_argument(
        "-c",
        "--coverm",
        required=True,
        help="Path to CoverM contig depth TSV (e.g. sample.depth.tsv.gz).",
    )
    parser.add_argument(
        "-s",
        "--sylph_tax",
        required=True,
        help="Path to sylph-tax MPA TSV (e.g. sample.sylphmpa).",
    )
    parser.add_argument(
        "-r",
        "--profile",
        required=True,
        help="Path to sylph profile TSV (e.g. sample.profile.tsv).",
    )
    parser.add_argument(
        "-g",
        "--gene_coverage",
        required=True,
        help="Path to gene-coverage TSV (e.g. sample.gene_coverage.tsv.gz).",
    )
    parser.add_argument(
        "-p",
        "--model_path",
        required=True,
        help="Path to model file (e.g. phage_activity_model_full.joblib).",
    )
    parser.add_argument(
        "-md",
        "--metadata_path",
        required=True,
        help="Path to model metadata file (e.g. phage_model_metadata_full.joblib).",
    )
    parser.add_argument(
        "-sid",
        "--sample_id",
        required=True,
        help="Sample ID.",
    )
    parser.add_argument(
        "--group",
        required=True,
        help="Coassembly or co-analysis group.",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        help="Output TSV path (uncompressed).",
    )
    parser.add_argument(
        "-so",
        "--sylph_tax_output",
        required=True,
        help="Annotated sylph-tax MPA path with virus lifestyle, PTH ratio, uninducible probability, and tier.",
    )
    parser.add_argument("--version", action="version", version="1.3.0")
    return parser.parse_args(args)


def write_tsv(df, output_path):
    """Write TSV without polars write_csv (sysinfo cgroup panic on SLURM)."""
    cols = df.columns
    with open(output_path, "w", encoding="utf-8", newline="") as fh:
        fh.write("\t".join(cols) + "\n")
        for row in df.iter_rows():
            fh.write("\t".join("" if v is None else str(v) for v in row) + "\n")


def _read_csv(path, **kwargs):
    kwargs.setdefault("null_values", ["NA", ""])
    try:
        df = pl.read_csv(path, **kwargs)
    except Exception:
        return None
    if df.height == 0:
        return None
    return df


def _parse_containment_frac(s):
    if s is None or not isinstance(s, str) or "/" not in s:
        return None
    try:
        a, b = s.split("/", 1)
        a, b = float(a), float(b)
        return float(a / b) if b else None
    except Exception:
        return None


def _empty_output():
    return pl.DataFrame(
        schema={
            "sample_id": pl.Utf8,
            "group": pl.Utf8,
            "species_cluster_id": pl.Int64,
            "uhvdb_id": pl.Utf8,
            "ictv_class": pl.Utf8,
            "predicted_inactive_probability": pl.Float64,
            "predicted_uninducible": pl.Int64,
            "inactive_confidence_tier": pl.Utf8,
        }
    )


def _col(df, name, dtype=None, alias=None):
    out_name = alias or name
    if name not in df.columns:
        expr = pl.lit(None)
        if dtype is not None:
            expr = expr.cast(dtype)
        return expr.alias(out_name)
    expr = pl.col(name)
    if dtype is not None:
        expr = expr.cast(dtype, strict=False)
    return expr.alias(out_name)


def with_bio_group_flags(df):
    cols = df.columns
    prep = []
    for name in ("pharokka_category", "phold_category", "empathi_annot", "pharokka_annot"):
        if name in cols:
            prep.append(pl.col(name).fill_null(""))
        else:
            prep.append(pl.lit("").alias(name))
    out = df.with_columns(prep).with_columns(
        [
            pl.col("empathi_annot")
            .str.split("|")
            .list.get(0, null_on_oob=True)
            .fill_null("")
            .alias("empathi_token0"),
            pl.col("empathi_annot")
            .str.split("|")
            .list.get(1, null_on_oob=True)
            .fill_null("")
            .alias("empathi_token1"),
        ]
    )
    return out.with_columns(
        [
            (
                (pl.col("pharokka_category") == "head and packaging")
                | pl.col("phold_category").str.contains("(?i)head|capsid|portal|terminase")
                | (pl.col("empathi_token0") == "pvp")
                | (pl.col("empathi_token0") == "packaging_assembly")
                | pl.col("empathi_token1").is_in(
                    ["capsid", "terminase", "portal", "head-tail_joining"]
                )
            ).alias("is_capsid_packaging"),
            (
                (pl.col("pharokka_category") == "DNA, RNA and nucleotide metabolism")
                | (pl.col("empathi_token0") == "DNA-associated")
                | (pl.col("empathi_token0") == "RNA-associated")
                | pl.col("empathi_token1").is_in(
                    ["nuclease", "annealing", "DNA_polymerase", "helicase"]
                )
            ).alias("is_dna_metabolism"),
            (
                (pl.col("pharokka_category") == "tail")
                | pl.col("phold_category").str.contains(r"(?i)\btail\b")
                | (pl.col("empathi_token1") == "tail")
            ).alias("is_tail"),
            (
                (pl.col("pharokka_category") == "lysis")
                | pl.col("phold_category").str.contains("(?i)lysis|holin|endolysin")
                | (pl.col("empathi_token0") == "lysis")
                | (pl.col("empathi_token0") == "cell_wall_depolymerase")
                | pl.col("empathi_token1").is_in(["lysis", "holin"])
            ).alias("is_lysis"),
            (
                (pl.col("pharokka_category") == "connector")
                | pl.col("phold_category").str.contains("(?i)connector|head-tail|head–tail")
            ).alias("is_connector"),
            (
                (pl.col("pharokka_category") == "transcription regulation")
                | (pl.col("empathi_token0") == "transcriptional_regulator")
                | (pl.col("empathi_token1") == "transcriptional_regulator")
            ).alias("is_transcription"),
            (
                (pl.col("pharokka_category") == "integration and excision")
                | pl.col("phold_category").str.contains("(?i)integrase|integration")
                | (pl.col("empathi_token1") == "integration")
            ).alias("is_integration"),
            (
                (
                    pl.col("pharokka_category")
                    == "moron, auxiliary metabolic gene and host takeover"
                )
                | pl.col("phold_category").str.contains(
                    r"(?i)auxiliary metabolic|host takeover|moron|anti[- ]?defen[cs]e"
                )
                | pl.col("empathi_token0").is_in(
                    ["amg", "auxiliary_metabolic", "host_takeover", "moron", "anti-defense"]
                )
                | pl.col("empathi_token1").is_in(
                    ["amg", "auxiliary_metabolic", "host_takeover", "moron", "anti-defense"]
                )
            ).alias("is_amg_host_takeover"),
        ]
    )


def load_coverm(path, sample_id, group):
    raw = _read_csv(path, separator="\t")
    if raw is None:
        return None
    cols = raw.columns
    if len(cols) < 6:
        return None
    return (
        raw.rename(
            {
                cols[0]: "contig_id",
                cols[1]: "trimmed_mean",
                cols[2]: "mean",
                cols[3]: "variance",
                cols[4]: "covered_bases",
                cols[5]: "length",
            }
        )
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                pl.lit(group).alias("group"),
                (pl.col("covered_bases") / pl.col("length")).alias("breadth"),
                (1 - math.e ** (-0.833 * pl.col("mean"))).alias("expected_breadth"),
            ]
        )
        .with_columns(
            pl.when(pl.col("expected_breadth") > 1e-6)
            .then(pl.col("breadth") / pl.col("expected_breadth"))
            .otherwise(None)
            .alias("breadth_ratio")
        )
        .with_columns(
            pl.when(pl.col("trimmed_mean") > 0)
            .then(pl.col("variance") / pl.col("trimmed_mean"))
            .otherwise(None)
            .alias("variance_ratio")
        )
    )


def load_sylph_tax(path, sample_id):
    raw = _read_csv(
        path,
        separator="\t",
        skip_rows=1,
        new_columns=[
            "clade_name",
            "taxonomic_abundance",
            "sequence_abundance",
            "ani",
            "coverage",
            "virus_host",
        ],
    )
    if raw is None or "clade_name" not in raw.columns:
        return pl.DataFrame(
            schema={"sample_id": pl.Utf8, "species_cluster_id": pl.Int64, "ani": pl.Float64}
        )
    return (
        raw.filter(pl.col("clade_name").str.starts_with("Viruses"))
        .filter(pl.col("clade_name").str.contains("t__"))
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                pl.col("clade_name")
                .str.replace(r".*vSPECIES-", "")
                .str.replace(r"\|.*", "")
                .cast(pl.Int64, strict=False)
                .alias("species_cluster_id"),
                pl.col("ani").cast(pl.Float64, strict=False),
            ]
        )
        .filter(pl.col("species_cluster_id").is_not_null())
        .unique(["sample_id", "species_cluster_id"])
        .select(["sample_id", "species_cluster_id", "ani"])
    )


def load_profile(path, sample_id, id_map):
    raw = _read_csv(path, separator="\t")
    if raw is None or "Contig_name" not in raw.columns:
        return pl.DataFrame(
            schema={
                "sample_id": pl.Utf8,
                "species_cluster_id": pl.Int64,
                "log_True_cov": pl.Float64,
                "log_tax_abund": pl.Float64,
                "log_seq_abund": pl.Float64,
                "Naive_ANI": pl.Float64,
                "containment_frac": pl.Float64,
                "kmers_reassigned": pl.Float64,
                "cov_evenness": pl.Float64,
                "True_cov_rank": pl.Float64,
            }
        )
    df = (
        raw.filter(pl.col("Contig_name").str.starts_with("UHVDB-"))
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                pl.col("Contig_name").alias("uhvdb_id"),
                _col(raw, "True_cov", pl.Float64),
                _col(raw, "Taxonomic_abundance", pl.Float64, "tax_abund"),
                _col(raw, "Sequence_abundance", pl.Float64, "seq_abund"),
                _col(raw, "Naive_ANI", pl.Float64),
                _col(raw, "Median_cov", pl.Float64),
                _col(raw, "Mean_cov_geq1", pl.Float64),
                _col(raw, "kmers_reassigned", pl.Float64),
                _col(raw, "Containment_ind", pl.Utf8),
            ]
        )
        .join(id_map, on="uhvdb_id", how="inner")
        .sort(["sample_id", "species_cluster_id", "tax_abund"], descending=[False, False, True])
        .unique(["sample_id", "species_cluster_id"], keep="first")
        .with_columns(
            [
                pl.col("Containment_ind")
                .map_elements(_parse_containment_frac, return_dtype=pl.Float64)
                .alias("containment_frac"),
                (pl.col("Median_cov") / pl.col("Mean_cov_geq1")).alias("cov_evenness"),
                pl.col("True_cov").log1p().alias("log_True_cov"),
                pl.col("tax_abund").fill_null(0).log1p().alias("log_tax_abund"),
                pl.col("seq_abund").fill_null(0).log1p().alias("log_seq_abund"),
            ]
        )
    )
    return (
        df.with_columns(
            [
                pl.col("True_cov").rank(method="average").over("sample_id").alias("_tc_rank"),
                pl.len().over("sample_id").alias("_n_in_sample"),
            ]
        )
        .with_columns((pl.col("_tc_rank") / pl.col("_n_in_sample")).alias("True_cov_rank"))
        .select(
            [
                "sample_id",
                "species_cluster_id",
                "log_True_cov",
                "log_tax_abund",
                "log_seq_abund",
                "Naive_ANI",
                "containment_frac",
                "kmers_reassigned",
                "cov_evenness",
                "True_cov_rank",
            ]
        )
    )


def gene_prop_agg(gene_raw):
    passing = gene_raw.filter(pl.col("breadth") > GENE_BREADTH_THRESHOLD)
    if passing.height == 0:
        return pl.DataFrame(
            schema={
                "sample_id": pl.Utf8,
                "genomovar_rep": pl.Utf8,
                "med_prop_capsid_packaging": pl.Float64,
                "med_prop_dna_metabolism": pl.Float64,
                "med_prop_tail": pl.Float64,
                "med_prop_lysis": pl.Float64,
                "med_prop_connector": pl.Float64,
                "med_prop_transcription": pl.Float64,
                "med_prop_integration": pl.Float64,
                "med_prop_amg_host_takeover": pl.Float64,
                "med_mcp_hallmark": pl.UInt32,
                "med_portal_hallmark": pl.UInt32,
                "med_terL_hallmark": pl.UInt32,
                "med_n_hallmarks": pl.UInt32,
            }
        )
    return (
        with_bio_group_flags(passing)
        .group_by(["sample_id", "genomovar_rep"])
        .agg(
            [
                pl.col("is_capsid_packaging").mean().alias("med_prop_capsid_packaging"),
                pl.col("is_dna_metabolism").mean().alias("med_prop_dna_metabolism"),
                pl.col("is_tail").mean().alias("med_prop_tail"),
                pl.col("is_lysis").mean().alias("med_prop_lysis"),
                pl.col("is_connector").mean().alias("med_prop_connector"),
                pl.col("is_transcription").mean().alias("med_prop_transcription"),
                pl.col("is_integration").mean().alias("med_prop_integration"),
                pl.col("is_amg_host_takeover").mean().alias("med_prop_amg_host_takeover"),
                (
                    ((pl.col("pharokka_annot") == "major head protein").sum() >= 1)
                    | ((pl.col("phold_category") == "major head protein").sum() >= 1)
                    | ((pl.col("empathi_annot") == "pvp|capsid|major_capsid").sum() >= 1)
                )
                .cast(pl.UInt32)
                .alias("med_mcp_hallmark"),
                (
                    ((pl.col("pharokka_annot") == "terminase large subunit").sum() >= 1)
                    | ((pl.col("phold_category") == "terminase large subunit").sum() >= 1)
                    | (
                        (
                            pl.col("empathi_annot")
                            == "DNA-associated|terminase|packaging_assembly"
                        ).sum()
                        >= 1
                    )
                )
                .cast(pl.UInt32)
                .alias("med_terL_hallmark"),
                (
                    ((pl.col("pharokka_annot") == "portal protein").sum() >= 1)
                    | ((pl.col("phold_category") == "portal protein").sum() >= 1)
                    | ((pl.col("empathi_annot") == "pvp|portal").sum() >= 1)
                )
                .cast(pl.UInt32)
                .alias("med_portal_hallmark"),
            ]
        )
        .with_columns(
            (pl.col("med_mcp_hallmark") + pl.col("med_terL_hallmark") + pl.col("med_portal_hallmark")).alias(
                "med_n_hallmarks"
            )
        )
    )


def gene_stats_agg(gene_raw, id_map, n_genes):
    if gene_raw.height == 0:
        return pl.DataFrame(
            schema={
                "sample_id": pl.Utf8,
                "species_cluster_id": pl.Int64,
                "gene_breadth_std": pl.Float64,
                "gene_breadth_cv": pl.Float64,
                "gene_occupancy": pl.Float64,
                "n_struct_genes": pl.Float64,
            }
        )
    struct = (
        (pl.col("pharokka_annot") == "major head protein")
        | (pl.col("phold_category") == "major head protein")
        | (pl.col("empathi_annot") == "pvp|capsid|major_capsid")
        | (pl.col("pharokka_annot") == "terminase large subunit")
        | (pl.col("phold_category") == "terminase large subunit")
        | (pl.col("empathi_annot") == "DNA-associated|terminase|packaging_assembly")
        | (pl.col("pharokka_annot") == "portal protein")
        | (pl.col("phold_category") == "portal protein")
        | (pl.col("empathi_annot") == "pvp|portal")
    )
    flagged = with_bio_group_flags(gene_raw)
    return (
        flagged.with_columns(struct.alias("is_struct"))
        .group_by(["sample_id", "genomovar_rep"])
        .agg(
            [
                pl.col("breadth").mean().alias("gene_breadth_mean"),
                pl.col("breadth").std().alias("gene_breadth_std"),
                pl.col("is_struct").sum().cast(pl.Float64).alias("n_struct_genes"),
                (pl.col("breadth") > GENE_BREADTH_THRESHOLD)
                .sum()
                .cast(pl.Float64)
                .alias("n_genes_covered"),
            ]
        )
        .with_columns(
            (pl.col("gene_breadth_std") / pl.col("gene_breadth_mean")).alias("gene_breadth_cv")
        )
        .join(id_map.rename({"uhvdb_id": "genomovar_rep"}), on="genomovar_rep", how="inner")
        .sort(
            ["sample_id", "species_cluster_id", "n_genes_covered"],
            descending=[False, False, True],
        )
        .unique(["sample_id", "species_cluster_id"], keep="first")
        .join(n_genes, on="species_cluster_id", how="left")
        .with_columns((pl.col("n_genes_covered") / pl.col("n_genes")).alias("gene_occupancy"))
        .select(
            [
                "sample_id",
                "species_cluster_id",
                "gene_breadth_std",
                "gene_breadth_cv",
                "gene_occupancy",
                "n_struct_genes",
            ]
        )
    )


def species_rep_metadata(uhvdb):
    df = uhvdb.filter(pl.col("seq_name") == pl.col("seqhash_rep")).unique(
        "species_cluster_id", keep="first"
    )
    return df.with_columns(
        [
            _col(df, "species_cluster_id", pl.Int64),
            _col(df, "uhvdb_id", pl.Utf8),
            _col(df, "ictv_class", pl.Utf8),
            _col(df, "virulent", pl.Float64, "med_virulent_score"),
            _col(df, "temperate", pl.Float64),
            _col(df, "phrog_integrases", pl.Float64),
            _col(df, "phrog_integration_excision", pl.Float64),
            _col(df, "empathi_integration", pl.Float64),
            (pl.col("integration_status") == "integrated").cast(pl.Float64).alias("is_integrated")
            if "integration_status" in df.columns
            else pl.lit(None).cast(pl.Float64).alias("is_integrated"),
            _col(df, "num_lysis", pl.Float64),
            _col(df, "num_tail", pl.Float64),
            _col(df, "num_capsid", pl.Float64),
            _col(df, "num_proteins", pl.Float64),
            _col(df, "mcp_hallmark", pl.Float64, "annot_mcp_hallmark"),
            _col(df, "terl_hallmark", pl.Float64, "annot_terl_hallmark"),
            _col(df, "portal_hallmark", pl.Float64, "annot_portal_hallmark"),
            _col(df, "n_hallmarks", pl.Float64, "annot_n_hallmarks"),
            _col(df, "virus_hallmarks", pl.Float64),
            _col(df, "aai_id", pl.Float64, "annot_aai_id"),
            _col(df, "aai_af", pl.Float64, "annot_aai_af"),
            _col(df, "aai_completeness", pl.Float64),
            (
                pl.when(pl.col("aai_confidence") == "low")
                .then(0.0)
                .when(pl.col("aai_confidence") == "medium")
                .then(1.0)
                .when(pl.col("aai_confidence") == "high")
                .then(2.0)
                .otherwise(1.0)
                .alias("aai_confidence_ord")
                if "aai_confidence" in df.columns
                else pl.lit(1.0).alias("aai_confidence_ord")
            ),
            _col(df, "Score", pl.Float64),
            _col(df, "completeness", pl.Float64),
            _col(df, "virus_score", pl.Float64),
            _col(df, "host_genes", pl.Float64),
            _col(df, "viral_genes", pl.Float64),
            _col(df, "contig_length", pl.Float64),
            _col(df, "n_genes", pl.Float64),
            (
                pl.col("topology").is_in(["DTR", "ITR"]).cast(pl.Float64).alias("has_terminal_repeats")
                if "topology" in df.columns
                else pl.lit(None).cast(pl.Float64).alias("has_terminal_repeats")
            ),
            (
                (pl.col("topology") == "DTR").cast(pl.Float64).alias("is_DTR")
                if "topology" in df.columns
                else pl.lit(None).cast(pl.Float64).alias("is_DTR")
            ),
            (
                pl.col("completeness_method")
                .cast(pl.Utf8)
                .str.contains("DTR")
                .cast(pl.Float64)
                .alias("cm_dtr")
                if "completeness_method" in df.columns
                else pl.lit(None).cast(pl.Float64).alias("cm_dtr")
            ),
            (
                (pl.col("checkv_quality") == "Complete").cast(pl.Int64).alias("complete_count")
                if "checkv_quality" in df.columns
                else pl.lit(None).cast(pl.Int64).alias("complete_count")
            ),
        ]
    ).with_columns(
        [
            ((pl.col("annot_aai_id") / 100) * pl.col("annot_aai_af")).alias("med_aai_id_af"),
            (pl.col("num_lysis") / (pl.col("contig_length") / 1000)).alias("num_lysis_per_kb"),
            (pl.col("num_tail") / (pl.col("contig_length") / 1000)).alias("num_tail_per_kb"),
            (pl.col("num_capsid") / (pl.col("contig_length") / 1000)).alias("num_capsid_per_kb"),
            (pl.col("num_proteins") / (pl.col("contig_length") / 1000)).alias(
                "num_proteins_per_kb"
            ),
            (pl.col("phrog_integrases") / (pl.col("contig_length") / 1000)).alias(
                "phrog_integrases_per_kb"
            ),
            (pl.col("phrog_integration_excision") / (pl.col("contig_length") / 1000)).alias(
                "phrog_integration_excision_per_kb"
            ),
            (pl.col("empathi_integration") / (pl.col("contig_length") / 1000)).alias(
                "empathi_integration_per_kb"
            ),
            (pl.col("annot_n_hallmarks") / (pl.col("contig_length") / 1000)).alias(
                "annot_n_hallmarks_per_kb"
            ),
            (pl.col("virus_hallmarks") / (pl.col("contig_length") / 1000)).alias(
                "virus_hallmarks_per_kb"
            ),
            pl.col("contig_length").log1p().alias("log_contig_length"),
            pl.col("n_genes").log1p().alias("log_n_genes"),
            (
                pl.col("viral_genes").cast(pl.Float64, strict=False)
                / (
                    pl.col("viral_genes").cast(pl.Float64, strict=False)
                    + pl.col("host_genes").cast(pl.Float64, strict=False)
                )
            ).alias("viral_gene_frac"),
        ]
    )


def confidence_tier(prob, t95, t90, t85):
    if prob is None or (isinstance(prob, float) and np.isnan(prob)):
        return "No prediction"
    if prob >= t95:
        return "95% precision"
    if prob >= t90:
        return "90% precision"
    if prob >= t85:
        return "85% precision"
    return "No prediction"


def _empty_lifestyle():
    return pl.DataFrame(schema={"species_cluster_id": pl.Int64, "lifestyle": pl.Utf8})


def _empty_host():
    return pl.DataFrame(
        schema={
            "species_cluster_id": pl.Int64,
            "final_species": pl.Utf8,
            "final_genus": pl.Utf8,
            "final_family": pl.Utf8,
        }
    )


def _empty_pth():
    return pl.DataFrame(schema={"species_cluster_id": pl.Int64, "pth_ratio": pl.Float64})


def _empty_inactivity():
    return pl.DataFrame(
        schema={
            "species_cluster_id": pl.Int64,
            "inactivity_probability": pl.Float64,
            "inactive_confidence_tier": pl.Utf8,
        }
    )


def _abund_col(df):
    if df is None or not df.columns:
        return None
    for name in ("relative_abundance", "taxonomic_abundance"):
        if name in df.columns:
            return name
    return df.columns[1] if len(df.columns) > 1 else None


def _extract_lineage_rank(lineage_col, prefix):
    return (
        pl.col(lineage_col)
        .cast(pl.Utf8)
        .str.replace_all(";", "|")
        .str.extract(rf"{prefix}([^|;]+)", 1)
    )


def _majority_host(df, col):
    if col not in df.columns:
        return pl.DataFrame(schema={"species_cluster_id": pl.Int64, col: pl.Utf8})
    ranked = (
        df.filter(pl.col(col).is_not_null())
        .group_by(["species_cluster_id", col])
        .agg(pl.len().alias("_n"))
        .sort(["species_cluster_id", "_n", col], descending=[False, True, False])
        .unique("species_cluster_id", keep="first")
        .select(["species_cluster_id", col])
    )
    return ranked


def species_lifestyle(uhvdb):
    if uhvdb is None or "species_cluster_id" not in uhvdb.columns:
        return _empty_lifestyle()
    has_integrated = (
        (pl.col("integration_status") == "integrated")
        if "integration_status" in uhvdb.columns
        else (pl.col("provirus") == "Yes")
        if "provirus" in uhvdb.columns
        else pl.lit(False)
    )
    temperate = (
        pl.col("temperate").cast(pl.Float64, strict=False) > 0.5
        if "temperate" in uhvdb.columns
        else pl.lit(False)
    )
    phrog = (
        pl.col("phrog_integration_excision").cast(pl.Float64, strict=False).fill_null(0) > 0
        if "phrog_integration_excision" in uhvdb.columns
        else pl.lit(False)
    )
    empathi = (
        pl.col("empathi_integration").cast(pl.Float64, strict=False).fill_null(0) > 0
        if "empathi_integration" in uhvdb.columns
        else pl.lit(False)
    )
    return (
        uhvdb.with_columns(pl.col("species_cluster_id").cast(pl.Int64, strict=False))
        .filter(pl.col("species_cluster_id").is_not_null())
        .group_by("species_cluster_id")
        .agg(
            [
                has_integrated.any().alias("has_integrated"),
                temperate.any().alias("has_bacphlip_temperate"),
                (phrog | empathi).any().alias("has_integration_gene"),
            ]
        )
        .with_columns(
            pl.when(
                pl.col("has_integrated")
                | pl.col("has_bacphlip_temperate")
                | pl.col("has_integration_gene")
            )
            .then(pl.lit("Temperate"))
            .otherwise(pl.lit("Virulent"))
            .alias("lifestyle")
        )
        .select(["species_cluster_id", "lifestyle"])
    )


def species_host(uhvdb):
    if uhvdb is None or "species_cluster_id" not in uhvdb.columns:
        return _empty_host()
    df = uhvdb.with_columns(pl.col("species_cluster_id").cast(pl.Int64, strict=False))
    if "genomovar_rep" in df.columns and "uhvdb_id" in df.columns:
        df = df.filter(pl.col("uhvdb_id") == pl.col("genomovar_rep"))
    elif "seq_name" in df.columns and "seqhash_rep" in df.columns:
        df = df.filter(pl.col("seq_name") == pl.col("seqhash_rep"))
    lineage_col = "host_lineage" if "host_lineage" in df.columns else (
        "final_host_lineage" if "final_host_lineage" in df.columns else None
    )
    if lineage_col is not None:
        df = df.with_columns(
            [
                _extract_lineage_rank(lineage_col, "s__").alias("final_species"),
                _extract_lineage_rank(lineage_col, "g__").alias("final_genus"),
                _extract_lineage_rank(lineage_col, "f__").alias("final_family"),
            ]
        )
    else:
        df = df.with_columns(
            [
                pl.lit(None).cast(pl.Utf8).alias("final_species"),
                pl.lit(None).cast(pl.Utf8).alias("final_genus"),
                pl.lit(None).cast(pl.Utf8).alias("final_family"),
            ]
        )
    if "final_host_pred" in df.columns:
        df = df.with_columns(
            pl.coalesce(
                [
                    pl.col("final_species"),
                    pl.when(pl.col("final_host_pred").cast(pl.Utf8).str.contains(r"\s"))
                    .then(pl.col("final_host_pred").cast(pl.Utf8))
                    .otherwise(None),
                ]
            ).alias("final_species")
        )
    hosts = (
        df.filter(pl.col("species_cluster_id").is_not_null())
        .unique("uhvdb_id" if "uhvdb_id" in df.columns else "species_cluster_id")
        .select(["species_cluster_id", "final_species", "final_genus", "final_family"])
    )
    return (
        hosts.select("species_cluster_id")
        .unique()
        .join(_majority_host(hosts, "final_species"), on="species_cluster_id", how="left")
        .join(_majority_host(hosts, "final_genus"), on="species_cluster_id", how="left")
        .join(_majority_host(hosts, "final_family"), on="species_cluster_id", how="left")
    )


def read_sylphmpa(path, as_strings=False):
    with open(path, encoding="utf-8") as fh:
        first = fh.readline()
    comment = first if first.startswith("#") else None
    skip = 1 if comment else 0
    kwargs = {"separator": "\t", "skip_rows": skip}
    if as_strings:
        kwargs["infer_schema_length"] = 0
    df = _read_csv(path, **kwargs)
    return comment, df


def write_sylphmpa(comment, df, output_path):
    cols = df.columns
    with open(output_path, "w", encoding="utf-8", newline="") as fh:
        if comment:
            fh.write(comment if comment.endswith("\n") else comment + "\n")
        fh.write("\t".join(cols) + "\n")
        for row in df.iter_rows():
            fh.write("\t".join("NA" if v is None else str(v) for v in row) + "\n")


def virus_abund_from_sylph(df, sample_id):
    abund = _abund_col(df)
    if df is None or abund is None or "clade_name" not in df.columns:
        return pl.DataFrame(
            schema={
                "sample_id": pl.Utf8,
                "species_cluster_id": pl.Int64,
                "virus_tax_abund": pl.Float64,
            }
        )
    return (
        df.filter(pl.col("clade_name").str.starts_with("Viruses"))
        .filter(pl.col("clade_name").str.contains(r"vSPECIES-\d+"))
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                pl.col("clade_name")
                .str.extract(r"vSPECIES-(\d+)", 1)
                .cast(pl.Int64, strict=False)
                .alias("species_cluster_id"),
                pl.col(abund).cast(pl.Float64, strict=False).alias("virus_tax_abund"),
            ]
        )
        .filter(pl.col("species_cluster_id").is_not_null())
        .filter(pl.col("virus_tax_abund") > 0)
        .group_by(["sample_id", "species_cluster_id"])
        .agg(pl.col("virus_tax_abund").max())
    )


def bacteria_from_sylph(df, sample_id):
    abund = _abund_col(df)
    empty = pl.DataFrame(
        schema={
            "sample_id": pl.Utf8,
            "species": pl.Utf8,
            "genus": pl.Utf8,
            "family": pl.Utf8,
            "host_tax_abund": pl.Float64,
        }
    )
    if df is None or abund is None or "clade_name" not in df.columns:
        return empty
    bac = (
        df.filter(
            pl.col("clade_name").str.starts_with("d__Bacteria")
            | pl.col("clade_name").str.contains(r"(^|\|)d__Bacteria")
        )
        .filter(pl.col("clade_name").str.contains(r"s__"))
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                pl.col("clade_name").str.replace_all(";", "|"),
                pl.col("clade_name").str.extract(r"s__([^|;]+)", 1).alias("species"),
                pl.col("clade_name").str.extract(r"g__([^|;]+)", 1).alias("genus"),
                pl.col("clade_name").str.extract(r"f__([^|;]+)", 1).alias("family"),
                pl.col(abund).cast(pl.Float64, strict=False).alias("host_tax_abund"),
            ]
        )
        .filter(pl.col("species").is_not_null())
        .filter(pl.col("host_tax_abund") > 0)
        .group_by(["sample_id", "species", "genus", "family"])
        .agg(pl.col("host_tax_abund").max())
    )
    return bac if bac.height else empty


def bacteria_from_profile(path, sample_id):
    empty = pl.DataFrame(
        schema={
            "sample_id": pl.Utf8,
            "species": pl.Utf8,
            "genus": pl.Utf8,
            "family": pl.Utf8,
            "host_tax_abund": pl.Float64,
        }
    )
    raw = _read_csv(path, separator="\t")
    if raw is None or "Contig_name" not in raw.columns:
        return empty
    abund = "Taxonomic_abundance" if "Taxonomic_abundance" in raw.columns else None
    if abund is None:
        return empty
    rest = pl.col("Contig_name").str.replace(r"^\S+\s+", "")
    bac = (
        raw.filter(~pl.col("Contig_name").str.starts_with("UHVDB-"))
        .with_columns(
            [
                pl.lit(sample_id).alias("sample_id"),
                rest.str.extract(r"^([A-Za-z0-9_]+ [A-Za-z0-9_.]+)", 1).alias("species"),
                rest.str.extract(r"^([A-Za-z0-9_]+)", 1).alias("genus"),
                pl.lit(None).cast(pl.Utf8).alias("family"),
                pl.col(abund).cast(pl.Float64, strict=False).alias("host_tax_abund"),
            ]
        )
        .filter(pl.col("species").is_not_null())
        .filter(pl.col("host_tax_abund") > 0)
        .group_by(["sample_id", "species", "genus", "family"])
        .agg(pl.col("host_tax_abund").sum())
    )
    return bac if bac.height else empty


def compute_pth_ratio(viruses, bac, host):
    empty = _empty_pth()
    if viruses.height == 0 or bac.height == 0 or host.height == 0:
        return empty
    viruses = viruses.join(host, on="species_cluster_id", how="left").with_columns(
        [
            pl.col("final_genus").alias("host_genus"),
            pl.col("final_family").alias("host_family"),
        ]
    )
    species_hits = (
        viruses.filter(pl.col("final_species").is_not_null() & (pl.col("virus_tax_abund") > 0))
        .join(
            bac.select(["sample_id", "species", "host_tax_abund"]),
            left_on=["sample_id", "final_species"],
            right_on=["sample_id", "species"],
            how="inner",
        )
        .with_columns(pl.lit("species_codetected").alias("host_match_method"))
    )
    matched = species_hits.select(["sample_id", "species_cluster_id"]).unique()
    genus_singleton = (
        bac.filter(pl.col("genus").is_not_null())
        .group_by(["sample_id", "genus"])
        .agg(
            [
                pl.len().alias("n_species"),
                pl.col("species").first().alias("species"),
                pl.col("host_tax_abund").first().alias("host_tax_abund"),
            ]
        )
        .filter(pl.col("n_species") == 1)
    )
    genus_hits = (
        viruses.join(matched, on=["sample_id", "species_cluster_id"], how="anti")
        .filter(pl.col("host_genus").is_not_null() & (pl.col("virus_tax_abund") > 0))
        .join(
            genus_singleton.select(["sample_id", "genus", "species", "host_tax_abund"]),
            left_on=["sample_id", "host_genus"],
            right_on=["sample_id", "genus"],
            how="inner",
        )
        .with_columns(pl.lit("genus_singleton").alias("host_match_method"))
    )
    matched = pl.concat(
        [matched, genus_hits.select(["sample_id", "species_cluster_id"]).unique()]
    ).unique()
    family_singleton = (
        bac.filter(pl.col("family").is_not_null())
        .group_by(["sample_id", "family"])
        .agg(
            [
                pl.len().alias("n_species"),
                pl.col("species").first().alias("species"),
                pl.col("host_tax_abund").first().alias("host_tax_abund"),
            ]
        )
        .filter(pl.col("n_species") == 1)
    )
    family_hits = (
        viruses.join(matched, on=["sample_id", "species_cluster_id"], how="anti")
        .filter(pl.col("host_family").is_not_null() & (pl.col("virus_tax_abund") > 0))
        .join(
            family_singleton.select(["sample_id", "family", "species", "host_tax_abund"]),
            left_on=["sample_id", "host_family"],
            right_on=["sample_id", "family"],
            how="inner",
        )
        .with_columns(pl.lit("family_singleton").alias("host_match_method"))
    )
    pth_cols = [
        "sample_id",
        "species_cluster_id",
        "virus_tax_abund",
        "host_tax_abund",
        "host_match_method",
    ]
    frames = [df.select(pth_cols) for df in (species_hits, genus_hits, family_hits) if df.height]
    if not frames:
        return empty
    pth = (
        pl.concat(frames)
        .with_columns((pl.col("virus_tax_abund") / pl.col("host_tax_abund")).alias("pth_ratio"))
        .filter(pl.col("host_tax_abund") > 0)
        .sort(
            ["sample_id", "species_cluster_id", "virus_tax_abund"],
            descending=[False, False, True],
        )
        .unique(["sample_id", "species_cluster_id"], keep="first")
    )
    method_counts = pth.group_by("host_match_method").len().sort("host_match_method")
    print(f"PTH ratios for {pth.height} virus species", file=sys.stderr)
    print(method_counts, file=sys.stderr)
    return pth.select(["species_cluster_id", "pth_ratio"])


def write_annotated_sylphmpa(sylph_tax_path, output_path, lifestyle, pth, inactivity):
    comment, df = read_sylphmpa(sylph_tax_path, as_strings=True)
    if df is None:
        df = pl.DataFrame(
            schema={
                "clade_name": pl.Utf8,
                "relative_abundance": pl.Float64,
                "sequence_abundance": pl.Float64,
                "ANI (if strain-level)": pl.Utf8,
                "Coverage (if strain-level)": pl.Utf8,
                "Virus_host (if viral)": pl.Utf8,
            }
        )
    df = df.with_columns(
        pl.when(pl.col("clade_name").str.contains(r"vSPECIES-\d+"))
        .then(pl.col("clade_name").str.extract(r"vSPECIES-(\d+)", 1).cast(pl.Int64, strict=False))
        .otherwise(None)
        .alias("_species_cluster_id")
    )
    df = (
        df.join(lifestyle, left_on="_species_cluster_id", right_on="species_cluster_id", how="left")
        .join(pth, left_on="_species_cluster_id", right_on="species_cluster_id", how="left")
        .join(
            inactivity,
            left_on="_species_cluster_id",
            right_on="species_cluster_id",
            how="left",
        )
        .drop("_species_cluster_id")
    )
    for old, new in SYLPHMPA_COLUMN_RENAMES.items():
        if old in df.columns:
            df = df.rename({old: new})
    for col in SYLPHMPA_OUTPUT_COLS:
        if col not in df.columns:
            df = df.with_columns(pl.lit(None).alias(col))
    write_sylphmpa(comment, df.select(SYLPHMPA_OUTPUT_COLS), output_path)


def finish(args, uhvdb, scored):
    lifestyle = species_lifestyle(uhvdb)
    host = species_host(uhvdb)
    _comment, sylph_df = read_sylphmpa(args.sylph_tax)
    viruses = virus_abund_from_sylph(sylph_df, args.sample_id)
    bac = bacteria_from_sylph(sylph_df, args.sample_id)
    if bac.height == 0:
        bac = bacteria_from_profile(args.profile, args.sample_id)
    pth = compute_pth_ratio(viruses, bac, host)
    if scored.height and "predicted_inactive_probability" in scored.columns:
        inactivity = scored.select(
            [
                pl.col("species_cluster_id").cast(pl.Int64, strict=False),
                pl.col("predicted_inactive_probability").alias("inactivity_probability"),
                pl.col("inactive_confidence_tier"),
            ]
        ).unique("species_cluster_id", keep="first")
    else:
        inactivity = _empty_inactivity()
    write_annotated_sylphmpa(
        args.sylph_tax, args.sylph_tax_output, lifestyle, pth, inactivity
    )
    write_tsv(scored, args.output)
    return 0


def main(args=None):
    args = parse_args(args)

    model_meta = joblib.load(args.metadata_path)
    pipeline = joblib.load(args.model_path)
    required_features = list(model_meta["numeric_cols"])
    t95 = float(model_meta["thresh_95"])
    t90 = float(model_meta["thresh_90"])
    t85 = float(model_meta["thresh_85"])
    ictv_class_filter = model_meta.get("ictv_class_filter", "Caudoviricetes")

    uhvdb = _read_csv(args.uhvdb_metadata, separator="\t")
    coverm = load_coverm(args.coverm, args.sample_id, args.group)
    if uhvdb is None or coverm is None:
        return finish(args, uhvdb, _empty_output())

    drop_cols = [c for c in META_HALLMARK_COLLISION_COLS if c in uhvdb.columns]
    uhvdb_for_join = uhvdb.drop(drop_cols) if drop_cols else uhvdb
    id_map = (
        uhvdb.select(["uhvdb_id", "species_cluster_id"])
        .unique("uhvdb_id")
        .with_columns(pl.col("species_cluster_id").cast(pl.Int64, strict=False))
    )
    meta_sp = species_rep_metadata(uhvdb)

    detections = (
        coverm.join(uhvdb_for_join, left_on="contig_id", right_on="uhvdb_id", how="left")
        .filter(pl.col("seq_name") == pl.col("seqhash_rep"))
        .with_columns(
            [
                pl.col("species_cluster_id").cast(pl.Int64, strict=False),
                pl.col("contig_id").alias("uhvdb_id"),
            ]
        )
        .unique(["species_cluster_id", "sample_id"], keep="first")
    )
    n_before = detections.height
    detections = detections.filter(pl.col("ictv_class") == ictv_class_filter)
    if detections.height == 0:
        print(
            f"No {ictv_class_filter} detections ({n_before} species-rep rows before ICTV filter)",
            file=sys.stderr,
        )
        return finish(args, uhvdb, _empty_output())

    gene_raw = _read_csv(args.gene_coverage, separator="\t")
    if gene_raw is None:
        gene_raw = pl.DataFrame(
            schema={
                "genomovar_rep": pl.Utf8,
                "breadth": pl.Float64,
                "mean_depth": pl.Float64,
                "pharokka_category": pl.Utf8,
                "pharokka_annot": pl.Utf8,
                "phold_category": pl.Utf8,
                "empathi_annot": pl.Utf8,
            }
        )
    else:
        gene_raw = (
            gene_raw.filter(pl.col("genomovar_rep").str.starts_with("UHVDB-"))
            .with_columns(pl.lit(args.sample_id).alias("sample_id"))
        )

    gene_prop = (
        gene_prop_agg(gene_raw)
        .join(id_map.rename({"uhvdb_id": "genomovar_rep"}), on="genomovar_rep", how="inner")
        .unique(["sample_id", "species_cluster_id"], keep="first")
    )
    gene_stats = gene_stats_agg(
        gene_raw, id_map, meta_sp.select(["species_cluster_id", "n_genes"])
    )
    prof = load_profile(args.profile, args.sample_id, id_map)
    sylph_ani = load_sylph_tax(args.sylph_tax, args.sample_id)

    features = (
        detections.select(
            [
                "sample_id",
                "group",
                "species_cluster_id",
                "uhvdb_id",
                "ictv_class",
                "breadth_ratio",
                "variance_ratio",
            ]
        )
        .join(
            meta_sp.drop(["uhvdb_id", "ictv_class"], strict=False),
            on="species_cluster_id",
            how="left",
        )
        .join(
            gene_prop.select(
                [
                    "sample_id",
                    "species_cluster_id",
                    "med_prop_capsid_packaging",
                    "med_prop_dna_metabolism",
                    "med_prop_tail",
                    "med_prop_lysis",
                    "med_prop_connector",
                    "med_prop_transcription",
                    "med_prop_integration",
                    "med_prop_amg_host_takeover",
                    "med_mcp_hallmark",
                    "med_portal_hallmark",
                    "med_terL_hallmark",
                    "med_n_hallmarks",
                ]
            ),
            on=["sample_id", "species_cluster_id"],
            how="left",
        )
        .join(prof, on=["sample_id", "species_cluster_id"], how="left")
        .join(gene_stats, on=["sample_id", "species_cluster_id"], how="left")
        .join(sylph_ani, on=["sample_id", "species_cluster_id"], how="left")
    )

    for col in required_features:
        if col not in features.columns:
            features = features.with_columns(pl.lit(None).cast(pl.Float64).alias(col))

    x_new = features.select(required_features).to_pandas()
    x_new = x_new.replace([np.inf, -np.inf], np.nan)
    probs = pipeline.predict_proba(x_new)[:, 1]
    pred = (probs >= t95).astype(int)
    tiers = [confidence_tier(p, t95, t90, t85) for p in probs]

    scored = features.with_columns(
        [
            pl.Series("predicted_inactive_probability", probs),
            pl.Series("predicted_uninducible", pred),
            pl.Series("inactive_confidence_tier", tiers),
        ]
    ).select(OUTPUT_COLS)

    print(
        f"Scored {scored.height} {ictv_class_filter} detections "
        f"(p>=thresh_95: {int(pred.sum())})",
        file=sys.stderr,
    )
    return finish(args, uhvdb, scored)


if __name__ == "__main__":
    sys.exit(main())
