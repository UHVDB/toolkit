#!/usr/bin/env python

import argparse
import sys

import polars as pl
import taxopy

DEFAULT_TAXDUMP_URL = (
    "https://github.com/shenwei356/gtdb-taxdump/releases/download/v0.6.0/gtdb-taxdump-R226.tar.gz"
)

CLASSIFY_COLS = [
    "uhvdb_id", "topology", "n_genes", "genetic_code", "virus_score",
    "n_hallmarks", "contig_length", "provirus", "proviral_length", "viral_genes",
    "host_genes", "completeness", "completeness_method", "kmer_freq", "Prediction",
    "Score", "uhvdb_virus_classification", "source_db", "db_type", "body_site",
]

HQFILTER_COLS = [
    "uhvdb_id", "aai_expected_length", "aai_completeness", "aai_confidence", "aai_error",
    "aai_num_hits", "aai_top_hit", "aai_id", "aai_af",
]

PROTEIN_ANNOT_COLS = [
    "bakta_acc", "foldseek_acc", "ips_id", "card_acc", "vfdb_acc",
    "pharokka_annot", "pharokka_category", "phold_category", "phold_annot",
    "empathi_annot",
]


def parse_args(args=None):
    parser = argparse.ArgumentParser(
        description="Build merged UHVDB metadata and protein annotation tables.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--seqhasher-tsv", required=True, help="Seqhasher TSV (original_id, hash).")
    parser.add_argument("--mapping-tsv", required=True, help="ID map TSV (original_id, uhvdb_id).")
    parser.add_argument("--classify-tsv", required=True, help="Renamed classify TSV.")
    parser.add_argument("--hqfilter-tsv", required=True, help="Renamed CheckV completeness TSV.")
    parser.add_argument("--hcfilter-tsv", required=True, help="Renamed hallmark-filter TSV.")
    parser.add_argument("--genomovar-info-tsv", required=True, help="Genomovar ANIREPS info TSV.")
    parser.add_argument("--species-info-tsv", required=True, help="Species ANIREPS info TSV.")
    parser.add_argument("--aaicluster-tsv", required=True, help="AAI cluster assignment TSV.")
    parser.add_argument("--taxonomy-tsv", required=True, help="ICTV taxonomy TSV.")
    parser.add_argument("--crisprhost-tsv", required=True, help="CRISPR host consensus TSV.")
    parser.add_argument("--phisthost-tsv", required=True, help="PHIST host consensus TSV.")
    parser.add_argument("--proteinhash-tsv", required=True, help="Protein hash TSV (protein_id, hash).")
    parser.add_argument("--bakta-tsv", required=True, help="Combined Bakta TSV.")
    parser.add_argument("--foldseek-tsv", required=True, help="Combined FoldSeek TSV.")
    parser.add_argument("--interproscan-tsv", required=True, help="Combined InterProScan TSV.")
    parser.add_argument("--card-tsv", required=True, help="Combined CARD TSV.")
    parser.add_argument("--vfdb-tsv", required=True, help="Combined VFDB TSV.")
    parser.add_argument("--pharokka-tsv", required=True, help="Combined Pharokka TSV.")
    parser.add_argument("--phold-tsv", required=True, help="Combined Phold TSV.")
    parser.add_argument("--empathi-csv", required=True, help="Combined Empathi CSV.")
    parser.add_argument("--uhvdb-metadata", required=False, help="Existing UHVDB metadata TSV.")
    parser.add_argument(
        "--uhvdb-protein-annotations",
        required=False,
        help="Existing UHVDB protein annotations TSV.",
    )
    parser.add_argument("--output-metadata", required=True, help="Output metadata TSV.")
    parser.add_argument(
        "--output-protein-annotations",
        required=True,
        help="Output protein annotations TSV.",
    )
    parser.add_argument("--version", action="version", version="1.0.0")
    return parser.parse_args(args)


def _read_tsv(path, **kwargs):
    kwargs.setdefault("separator", "\t")
    kwargs.setdefault("null_values", ["NA"])
    try:
        df = pl.read_csv(path, **kwargs)
    except Exception:
        return None
    if df.height == 0:
        return None
    return df


def _normalise_seq_name(df):
    if df is None:
        return None
    if "seq_name" not in df.columns and "original_id" in df.columns:
        return df.rename({"original_id": "seq_name"})
    return df


def _select_cols(df, cols):
    return df.select([col for col in cols if col in df.columns])


def _rep_column(df, *candidates):
    for name in candidates:
        if name in df.columns:
            return name
    raise ValueError(f"None of {candidates} found in columns: {df.columns}")


def _read_mapping(path):
    mapping = _read_tsv(path)
    if mapping is None:
        mapping = pl.read_csv(
            path,
            separator="\t",
            has_header=False,
            new_columns=["original_id", "uhvdb_id"],
        )
    if "uhvdb_id" not in mapping.columns and "new_id" in mapping.columns:
        mapping = mapping.rename({"new_id": "uhvdb_id"})
    if "original_id" not in mapping.columns:
        mapping = mapping.rename({mapping.columns[0]: "original_id"})
        if "uhvdb_id" not in mapping.columns:
            mapping = mapping.rename({mapping.columns[1]: "uhvdb_id"})
    return mapping.select(["original_id", "uhvdb_id"])


def _concat_new_and_existing(new_df, existing_df, cols):
    frames = [_select_cols(new_df, cols).unique("uhvdb_id")]
    if existing_df is not None:
        present = [col for col in cols if col in existing_df.columns]
        if "uhvdb_id" in present:
            frames.append(existing_df.select(present).unique("uhvdb_id"))
    return pl.concat(frames, how="vertical_relaxed").unique("uhvdb_id", keep="first")


def create_base_metadata(args):
    seqhasher = _read_tsv(args.seqhasher_tsv)
    if seqhasher is None:
        raise ValueError("Seqhasher TSV is empty or unreadable.")
    if "original_id" not in seqhasher.columns:
        seqhasher = seqhasher.rename({seqhasher.columns[0]: "original_id", seqhasher.columns[1]: "hash"})

    mapping = _read_mapping(args.mapping_tsv)
    seqhash_reps = (
        mapping
        .unique("uhvdb_id", keep="first")
        .select(["uhvdb_id", pl.col("original_id").alias("seqhash_rep")])
    )
    new_id_rows = (
        seqhasher
        .join(mapping, on="original_id", how="inner")
        .join(seqhash_reps, on="uhvdb_id", how="left")
        .rename({"original_id": "seq_name"})
        .select(["seq_name", "hash", "seqhash_rep", "uhvdb_id"])
    )

    existing = _normalise_seq_name(_read_tsv(args.uhvdb_metadata) if args.uhvdb_metadata else None)
    id_frames = [new_id_rows]
    if existing is not None:
        id_cols = [col for col in ["seq_name", "hash", "seqhash_rep", "uhvdb_id"] if col in existing.columns]
        if "seq_name" in id_cols and "uhvdb_id" in id_cols:
            old_id_rows = existing.select(id_cols)
            if "seqhash_rep" not in old_id_rows.columns:
                old_id_rows = old_id_rows.with_columns(pl.col("seq_name").alias("seqhash_rep"))
            # Keep every existing genome row (seq_name), including extra source
            # sequences that share a uhvdb_id. unique("uhvdb_id") would drop them.
            id_frames.append(old_id_rows)
    id_df = pl.concat(id_frames, how="vertical_relaxed").unique("seq_name", keep="first")

    classify = _read_tsv(args.classify_tsv)
    if classify is None:
        raise ValueError("Classify TSV is empty or unreadable.")
    classify_df = _concat_new_and_existing(classify, existing, CLASSIFY_COLS)

    hqfilter = _read_tsv(args.hqfilter_tsv)
    if hqfilter is None:
        raise ValueError("HQ filter TSV is empty or unreadable.")
    hqfilter_df = _concat_new_and_existing(hqfilter, existing, HQFILTER_COLS)

    hcfilter = _read_tsv(
        args.hcfilter_tsv,
        schema_overrides={"virus_hallmarks": pl.Int64, "plasmid_hallmarks": pl.Int64},
    )
    if hcfilter is None:
        hcfilter = pl.DataFrame(schema={
            "uhvdb_id": pl.String,
            "virus_hallmarks": pl.Int64,
            "plasmid_hallmarks": pl.Int64,
        })
    hcfilter_cols = ["uhvdb_id", "virus_hallmarks", "plasmid_hallmarks"]
    hcfilter_df = _concat_new_and_existing(hcfilter, existing, hcfilter_cols)

    genomovars = _read_tsv(args.genomovar_info_tsv)
    if genomovars is None:
        raise ValueError("Genomovar info TSV is empty or unreadable.")
    genomovar_rep_col = _rep_column(genomovars, "genomovars_rep", "genomovar_rep", "votu_rep")
    genomovars = (
        genomovars
        .select(["uhvdb_id", genomovar_rep_col, "cluster_id"])
        .unique("uhvdb_id")
        .rename({genomovar_rep_col: "genomovar_rep", "cluster_id": "genomovar_cluster_id"})
    )

    species = _read_tsv(args.species_info_tsv)
    if species is None:
        raise ValueError("Species info TSV is empty or unreadable.")
    species_rep_col = _rep_column(species, "species_rep", "votu_rep")
    species = (
        species
        .select(["uhvdb_id", species_rep_col, "cluster_id"])
        .unique("uhvdb_id")
        .rename({species_rep_col: "species_rep", "cluster_id": "species_cluster_id"})
    )

    aaicluster = _read_tsv(args.aaicluster_tsv)
    if aaicluster is None:
        raise ValueError("AAI cluster TSV is empty or unreadable.")

    return (
        id_df
        .join(classify_df, on="uhvdb_id", how="left")
        .join(hqfilter_df, on="uhvdb_id", how="left")
        .join(hcfilter_df, on="uhvdb_id", how="left")
        .join(genomovars, on="uhvdb_id", how="left")
        .join(species, left_on="genomovar_rep", right_on="uhvdb_id", how="left")
        .join(aaicluster.unique("uhvdb_id"), left_on="species_rep", right_on="uhvdb_id", how="left")
    )


def add_taxonomy(metadata_df, args, existing):
    taxonomy = _read_tsv(args.taxonomy_tsv)
    if taxonomy is None:
        return metadata_df
    taxonomy_df1 = taxonomy
    if "normscore" in taxonomy_df1.columns:
        taxonomy_df1 = taxonomy_df1.with_columns([pl.col("normscore").fill_null(0)])
        taxonomy_df1 = taxonomy_df1.sort("normscore", descending=True)
    taxonomy_df1 = taxonomy_df1.unique("uhvdb_id", maintain_order=True)
    rename_map = {
        "taxonomy": "genomad_taxonomy",
        "ref": "ictv_ref",
        "normscore": "ictv_proteinsimilarity",
        "Class": "ictv_class",
        "Order": "ictv_order",
        "Family": "ictv_family",
        "Genus": "ictv_genus",
        "Species": "ictv_species",
    }
    taxonomy_df1 = taxonomy_df1.rename({
        src: dst for src, dst in rename_map.items() if src in taxonomy_df1.columns
    })
    frames = [taxonomy_df1]
    if existing is not None:
        present = [col for col in taxonomy_df1.columns if col in existing.columns]
        if "uhvdb_id" in present:
            frames.append(
                existing
                .select(present)
                .filter(pl.col("uhvdb_id").is_in(set(metadata_df["genomovar_rep"])))
                .filter(~pl.col("uhvdb_id").is_in(set(taxonomy_df1["uhvdb_id"])))
            )
    taxonomy_df2 = pl.concat(frames, how="vertical_relaxed")
    return metadata_df.join(taxonomy_df2, left_on="genomovar_rep", right_on="uhvdb_id", how="left")


def add_host_predictions(metadata_df, args, existing):
    crisprhost = _read_tsv(args.crisprhost_tsv)
    if crisprhost is None:
        crisprhost_df1 = pl.DataFrame(schema={"uhvdb_id": pl.String})
    else:
        crisprhost_df1 = (
            crisprhost
            .group_by("uhvdb_id")
            .agg([
                pl.col("top_taxonomy").filter(pl.col("rank") == "species").first().alias("crispr_gtdb_r220_species"),
                pl.col("total_connections").filter(pl.col("rank") == "species").first().alias("crispr_species_connections"),
                pl.col("agreement").filter(pl.col("rank") == "species").first().alias("crispr_species_agreement"),
                pl.col("top_taxonomy").filter(pl.col("rank") == "genus").first().alias("crispr_gtdb_r220_genus"),
                pl.col("total_connections").filter(pl.col("rank") == "genus").first().alias("crispr_genus_connections"),
                pl.col("agreement").filter(pl.col("rank") == "genus").first().alias("crispr_genus_agreement"),
                pl.col("top_taxonomy").filter(pl.col("rank") == "family").first().alias("crispr_gtdb_r220_family"),
                pl.col("total_connections").filter(pl.col("rank") == "family").first().alias("crispr_family_connections"),
                pl.col("agreement").filter(pl.col("rank") == "family").first().alias("crispr_family_agreement"),
            ])
        )
    crispr_frames = [crisprhost_df1]
    if existing is not None and "uhvdb_id" in existing.columns:
        present = [col for col in crisprhost_df1.columns if col in existing.columns]
        if present and "uhvdb_id" in present:
            crispr_frames.append(
                existing
                .select(present)
                .filter(pl.col("uhvdb_id").is_in(set(metadata_df["genomovar_rep"])))
                .filter(~pl.col("uhvdb_id").is_in(set(crisprhost_df1["uhvdb_id"])))
            )
    crisprhost_df2 = pl.concat(crispr_frames, how="vertical_relaxed")

    phisthost = _read_tsv(args.phisthost_tsv)
    if phisthost is None:
        phisthost_df1 = pl.DataFrame(schema={"uhvdb_id": pl.String})
    else:
        phisthost_df1 = (
            phisthost
            .group_by("uhvdb_id")
            .agg([
                pl.col("consensus_taxonomy").filter(pl.col("rank") == "species").first().str.replace("s__", "").alias("phist_gtdb_r226_species"),
                pl.col("total_connections").filter(pl.col("rank") == "species").first().alias("phist_species_connections"),
                pl.col("agreement").filter(pl.col("rank") == "species").first().alias("phist_species_agreement"),
                pl.col("consensus_taxonomy").filter(pl.col("rank") == "genus").first().str.replace("g__", "").alias("phist_gtdb_r226_genus"),
                pl.col("total_connections").filter(pl.col("rank") == "genus").first().alias("phist_genus_connections"),
                pl.col("agreement").filter(pl.col("rank") == "genus").first().alias("phist_genus_agreement"),
                pl.col("consensus_taxonomy").filter(pl.col("rank") == "family").first().str.replace("f__", "").alias("phist_gtdb_r226_family"),
                pl.col("total_connections").filter(pl.col("rank") == "family").first().alias("phist_family_connections"),
                pl.col("agreement").filter(pl.col("rank") == "family").first().alias("phist_family_agreement"),
            ])
            .with_columns([
                pl.col("phist_species_agreement").cast(pl.Float64),
                pl.col("phist_genus_agreement").cast(pl.Float64),
                pl.col("phist_family_agreement").cast(pl.Float64),
            ])
        )
    phist_frames = [phisthost_df1]
    if existing is not None and "uhvdb_id" in existing.columns:
        present = [col for col in phisthost_df1.columns if col in existing.columns]
        if present and "uhvdb_id" in present:
            phist_frames.append(
                existing
                .select(present)
                .filter(pl.col("uhvdb_id").is_in(set(metadata_df["genomovar_rep"])))
                .filter(~pl.col("uhvdb_id").is_in(set(phisthost_df1["uhvdb_id"])))
            )
    phisthost_df2 = pl.concat(phist_frames, how="vertical_relaxed")

    combined_host_df1 = (
        crisprhost_df2
        .join(phisthost_df2, on="uhvdb_id", how="left")
        .with_columns([
            pl.col(col).cast(pl.Int64)
            for col in [
                "phist_species_connections", "crispr_species_connections",
                "phist_genus_connections", "crispr_genus_connections",
                "phist_family_connections", "crispr_family_connections",
            ]
            if col in crisprhost_df2.columns or col in phisthost_df2.columns
        ])
    )
    if "phist_species_connections" in combined_host_df1.columns and "crispr_species_connections" in combined_host_df1.columns:
        combined_host_df1 = combined_host_df1.with_columns([
            pl.when((pl.col("phist_species_connections") >= pl.col("crispr_species_connections")) & (pl.col("phist_species_connections") > 0)).then(pl.col("phist_gtdb_r226_species"))
            .when(pl.col("phist_species_connections") < pl.col("crispr_species_connections")).then(pl.col("crispr_gtdb_r220_species"))
            .when((pl.col("phist_genus_connections") >= pl.col("crispr_genus_connections")) & (pl.col("phist_genus_connections") > 0)).then(pl.col("phist_gtdb_r226_genus"))
            .when(pl.col("phist_genus_connections") < pl.col("crispr_genus_connections")).then(pl.col("crispr_gtdb_r220_genus"))
            .when((pl.col("phist_family_connections") >= pl.col("crispr_family_connections")) & (pl.col("phist_family_connections") > 0)).then(pl.col("phist_gtdb_r226_family"))
            .when(pl.col("phist_family_connections") < pl.col("crispr_family_connections")).then(pl.col("crispr_gtdb_r220_family"))
            .otherwise(pl.lit(None))
            .alias("final_host_pred")
        ])
    else:
        combined_host_df1 = combined_host_df1.with_columns(pl.lit(None).alias("final_host_pred"))

    unique_final_species = (
        combined_host_df1.select("final_host_pred").drop_nulls().unique().to_series().to_list()
    )
    species_to_lineage = {}
    if unique_final_species:
        taxdb_r226 = taxopy.TaxDb(taxdump_url=DEFAULT_TAXDUMP_URL)
        rank_prefix = [
            ("superkingdom", "s__"),
            ("phylum", "p__"),
            ("class", "c__"),
            ("order", "o__"),
            ("family", "f__"),
            ("genus", "g__"),
            ("species", "s__"),
        ]
        for sp in unique_final_species:
            taxids = taxopy.taxid_from_name(sp, taxdb_r226)
            if not taxids:
                continue
            taxon = taxopy.Taxon(taxids[0], taxdb_r226)
            rank_name = taxon.rank_name_dictionary
            lineage_parts = [
                f"{prefix}{rank_name[rank]}"
                for rank, prefix in rank_prefix
                if rank in rank_name and rank_name[rank] is not None
            ]
            species_to_lineage[sp] = ";".join(lineage_parts)

    combined_host_df2 = combined_host_df1.with_columns([
        pl.col("final_host_pred").replace(species_to_lineage).str.replace(r"^s__", "d__").alias("final_host_lineage"),
    ])
    return metadata_df.join(combined_host_df2, left_on="genomovar_rep", right_on="uhvdb_id", how="left")


def _empty_annot(cols):
    return pl.DataFrame(schema={col: pl.String for col in cols})


def add_protein_annotations(metadata_df, args, existing_prot):
    prothash_frames = []
    prothash = _read_tsv(args.proteinhash_tsv)
    if prothash is not None and "protein_id" in prothash.columns:
        prothash_frames.append(_select_cols(prothash, ["protein_id", "hash"]))
    if existing_prot is not None and "protein_id" in existing_prot.columns:
        prothash_frames.append(_select_cols(existing_prot, ["protein_id", "hash"]))
    if not prothash_frames:
        metadata_df.write_csv(args.output_metadata, separator="\t")
        pl.DataFrame().write_csv(args.output_protein_annotations, separator="\t")
        return
    current_reps = set(metadata_df["genomovar_rep"].drop_nulls().to_list())
    prothash_df = (
        pl.concat(prothash_frames, how="vertical_relaxed")
        .unique("protein_id", keep="first")
        .with_columns([pl.col("protein_id").str.replace(r"_[^_]*$", "").alias("genomovar_rep")])
        .filter(pl.col("genomovar_rep").is_in(current_reps))
    )
    try:
        bakta_df = pl.read_csv(
            args.bakta_tsv,
            separator="\t",
            columns=["Locus Tag", "Accession"],
            new_columns=["hash", "bakta_acc"],
            null_values=["-"],
            skip_rows=5,
            ignore_errors=True,
        )
    except Exception:
        bakta_df = _empty_annot(["hash", "bakta_acc"])
    try:
        foldseek_df = pl.read_csv(
            args.foldseek_tsv,
            separator="\t",
            has_header=False,
            columns=["column_1", "column_2"],
            new_columns=["hash", "foldseek_acc"],
        )
    except Exception:
        foldseek_df = _empty_annot(["hash", "foldseek_acc"])
    try:
        ips_df = (
            pl.read_csv(
                args.interproscan_tsv,
                separator="\t",
                ignore_errors=True,
                has_header=False,
                columns=["column_1", "column_5"],
                new_columns=["hash", "ips_id"],
            )
            .group_by("hash")
            .agg(pl.col("ips_id").cast(pl.String).str.join(",").alias("ips_id"))
        )
    except Exception:
        ips_df = _empty_annot(["hash", "ips_id"])
    try:
        card_df = pl.read_csv(
            args.card_tsv,
            separator="\t",
            ignore_errors=True,
            has_header=False,
            columns=["column_1", "column_2"],
            new_columns=["hash", "card_acc"],
        )
    except Exception:
        card_df = _empty_annot(["hash", "card_acc"])
    try:
        vfdb_df = pl.read_csv(
            args.vfdb_tsv,
            separator="\t",
            ignore_errors=True,
            has_header=False,
            columns=["column_1", "column_2"],
            new_columns=["hash", "vfdb_acc"],
        )
    except Exception:
        vfdb_df = _empty_annot(["hash", "vfdb_acc"])
    try:
        pharokka_df = (
            pl.read_csv(
                args.pharokka_tsv,
                separator="\t",
                ignore_errors=True,
                columns=["ID", "annot", "category"],
                new_columns=["hash", "pharokka_annot", "pharokka_category"],
            )
            .filter(pl.col("pharokka_annot") != "hypothetical protein")
        )
    except Exception:
        pharokka_df = _empty_annot(["hash", "pharokka_annot", "pharokka_category"])
    try:
        phold_df = (
            pl.read_csv(
                args.phold_tsv,
                separator="\t",
                ignore_errors=True,
                columns=["cds_id", "function", "product"],
                new_columns=["hash", "phold_category", "phold_annot"],
            )
            .filter(pl.col("phold_category") != "unknown function")
        )
    except Exception:
        phold_df = _empty_annot(["hash", "phold_category", "phold_annot"])
    try:
        empathi_df = pl.read_csv(
            args.empathi_csv,
            ignore_errors=True,
            columns=["", "Annotation"],
            new_columns=["hash", "empathi_annot"],
        )
    except Exception:
        empathi_df = _empty_annot(["hash", "empathi_annot"])

    # Keep every protein on current genomovar reps. FUNCTION only annotates novel
    # hashes, so shared-hash proteins must left-join Bakta/PHROG/Empathi and then
    # copy existing annotations onto the new protein_id by hash.
    combined_protein_annotations_df1 = (
        prothash_df
        .join(bakta_df, on="hash", how="left")
        .join(foldseek_df, on="hash", how="left")
        .join(ips_df, on="hash", how="left")
        .join(card_df, on="hash", how="left")
        .join(vfdb_df, on="hash", how="left")
        .join(pharokka_df, on="hash", how="left")
        .join(phold_df, on="hash", how="left")
        .join(empathi_df, on="hash", how="left")
    )
    if existing_prot is not None and "hash" in existing_prot.columns:
        old_annot_cols = [col for col in PROTEIN_ANNOT_COLS if col in existing_prot.columns]
        if old_annot_cols:
            existing_by_hash = (
                existing_prot
                .filter(pl.col("hash").is_not_null())
                .unique("hash", keep="first")
                .select(["hash"] + old_annot_cols)
                .rename({col: f"{col}__old" for col in old_annot_cols})
            )
            combined_protein_annotations_df1 = combined_protein_annotations_df1.join(
                existing_by_hash, on="hash", how="left"
            ).with_columns([
                pl.coalesce([pl.col(col), pl.col(f"{col}__old")]).alias(col)
                for col in old_annot_cols
            ]).drop([f"{col}__old" for col in old_annot_cols])

    frames = [combined_protein_annotations_df1]
    if existing_prot is not None:
        existing_keep = (
            existing_prot
            .filter(pl.col("genomovar_rep").is_in(current_reps))
        )
        if "protein_id" in existing_keep.columns:
            existing_keep = existing_keep.filter(
                ~pl.col("protein_id").is_in(set(combined_protein_annotations_df1["protein_id"]))
            )
        frames.append(existing_keep)
    combined_protein_annotations_df2 = pl.concat(frames, how="vertical_relaxed")
    combined_protein_annotations_df2.write_csv(args.output_protein_annotations, separator="\t")

    combined_protein_annotations_df3 = (
        combined_protein_annotations_df2
        .group_by("genomovar_rep")
        .agg([
            pl.len().alias("num_proteins"),
            ((pl.col("bakta_acc").is_not_null()) | (pl.col("foldseek_acc").is_not_null()) | (pl.col("ips_id").is_not_null())).sum().alias("num_uniprot_ips"),
            (pl.col("card_acc").is_not_null()).sum().alias("num_card"),
            (pl.col("vfdb_acc").is_not_null()).sum().alias("num_vfdb"),
            ((pl.col("pharokka_category") == "integration and excision") | (pl.col("phold_category") == "integration and excision") | (pl.col("empathi_annot").str.contains("integration"))).sum().alias("num_integrase_excision"),
            ((pl.col("pharokka_category").fill_null("").str.contains("tail")) | (pl.col("phold_category").fill_null("").str.contains("tail")) | (pl.col("empathi_annot").fill_null("").str.contains("tail"))).sum().alias("num_tail"),
            ((pl.col("pharokka_category").fill_null("").str.contains("head")) | (pl.col("phold_category").fill_null("").str.contains("head")) | (pl.col("empathi_annot").fill_null("").str.contains("capsid"))).sum().alias("num_capsid"),
            ((pl.col("pharokka_category").fill_null("").str.contains("lysis")) | (pl.col("phold_category").fill_null("").str.contains("lysis")) | (pl.col("empathi_annot").fill_null("").str.contains("lysis"))).sum().alias("num_lysis"),
            (((pl.col("pharokka_annot") == "major head protein").sum() == 1) | ((pl.col("phold_category") == "major head protein").sum() == 1) | ((pl.col("empathi_annot") == "pvp|capsid|major_capsid").sum() == 1)).sum().alias("mcp_hallmark"),
            (((pl.col("pharokka_annot") == "terminase large subunit").sum() == 1) | ((pl.col("phold_category") == "terminase large subunit").sum() == 1) | ((pl.col("empathi_annot") == "DNA-associated|terminase|packaging_assembly").sum() == 1)).sum().alias("terl_hallmark"),
            (((pl.col("pharokka_annot") == "portal protein").sum() == 1) | ((pl.col("phold_category") == "portal protein").sum() == 1) | ((pl.col("empathi_annot") == "pvp|portal").sum() == 1)).sum().alias("portal_hallmark"),
        ])
    )
    metadata_df.join(combined_protein_annotations_df3, on="genomovar_rep", how="left").write_csv(
        args.output_metadata, separator="\t"
    )


def main(args=None):
    args = parse_args(args)
    existing = _normalise_seq_name(_read_tsv(args.uhvdb_metadata) if args.uhvdb_metadata else None)
    existing_prot = _read_tsv(args.uhvdb_protein_annotations) if args.uhvdb_protein_annotations else None
    metadata_df = create_base_metadata(args)
    metadata_df = add_taxonomy(metadata_df, args, existing)
    metadata_df = add_host_predictions(metadata_df, args, existing)
    add_protein_annotations(metadata_df, args, existing_prot)


if __name__ == "__main__":
    sys.exit(main())
