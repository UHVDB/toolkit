#!/usr/bin/env python

import argparse
import gzip

import polars as pl


def parse_args(args=None):
    description = "Extract ANI reps from MCL clusters."
    epilog = "Example usage: python uhvdb_anireps.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-m",
        "--mcl",
        help="Path to MCL clusters.",
    )
    parser.add_argument(
        "-n",
        "--new_fna",
        help="Path to FASTA of new sequences (gzipped or plain).",
    )
    parser.add_argument(
        "-t",
        "--tsv",
        help="Path to the classify TSV file output by UHVDB/classify.",
    )
    parser.add_argument(
        "-c",
        "--completeness",
        help="Path to the completeness TSV file from running CheckV2.",
    )
    parser.add_argument(
        "-u",
        "--uhvdb_metadata",
        help="Path to the UHVDB metadata TSV file from previous version of UHVDB.",
    )
    parser.add_argument(
        "-s",
        "--cluster_level",
        help="The cluster level (e.g., genomovar, species).",
    )
    parser.add_argument(
        "-r",
        "--output_reps",
        help="Output TSV with clusters that have been assigned a representative.",
    )
    parser.add_argument(
        "-e",
        "--output_new_reps",
        help="Output TSV with new clusters that have been assigned a representative.",
    )
    parser.add_argument(
        "-l",
        "--cluster_info",
        help="Output TSV with cluster info.",
    )
    parser.add_argument('--version', action='version', version='1.2.0')
    return parser.parse_args(args)


def read_fasta_ids(fna_path):
    """Return sequence IDs from a FASTA file in file order."""
    opener = gzip.open if str(fna_path).endswith('.gz') else open
    ids = []
    with opener(fna_path, 'rt') as handle:
        for line in handle:
            if line.startswith('>'):
                ids.append(line[1:].split()[0])
    return ids


def load_mcl_clusters(mcl):
    """Assign MCL cluster IDs (1-based, one cluster per non-empty input line)."""
    clusters = {}
    cluster_id = 0
    with gzip.open(mcl, 'rt') as mcl_file:
        for line in mcl_file:
            cluster_id += 1
            for node in line.strip().split():
                clusters[node] = cluster_id
    return clusters, cluster_id


def add_singleton_clusters(clusters, cluster_id, sequence_ids):
    """Assign each unclustered sequence its own cluster ID, preserving input order."""
    for sequence in sequence_ids:
        if sequence not in clusters:
            cluster_id += 1
            clusters[sequence] = cluster_id
    return clusters, cluster_id


def old_sequence_ids(metadata_df, cluster_level):
    """
    Old sequence IDs that were previously taken from old FASTA headers.

    Equivalent sets:
    - genomovars: unique uhvdb_id values (unique-virus FASTA)
    - species: unique genomovar_rep values (genomovar-rep FASTA)
    """
    if cluster_level == 'species':
        return (
            metadata_df
            .get_column('genomovar_rep')
            .drop_nulls()
            .unique(maintain_order=True)
            .to_list()
        )
    return (
        metadata_df
        .get_column('uhvdb_id')
        .unique(maintain_order=True)
        .to_list()
    )


def dedupe_by_uhvdb_id(df):
    """
    Collapse to one row per uhvdb_id.

    When the frame has completeness_method, favour DTR rows so metadata
    duplicates that disagree on method do not silently drop circular genomes.
    Otherwise favour rows with a non-null aai_expected_length.
    """
    keep_cols = df.columns
    if 'completeness_method' in keep_cols:
        ranked = df.with_columns(
            pl.col('completeness_method')
            .cast(pl.String)
            .str.contains('DTR')
            .fill_null(False)
            .alias('_prefer')
        )
    elif 'aai_expected_length' in keep_cols:
        ranked = df.with_columns(
            pl.col('aai_expected_length').is_not_null().alias('_prefer')
        )
    else:
        ranked = df.with_columns(pl.lit(False).alias('_prefer'))

    return (
        ranked
        .sort('_prefer', descending=True, maintain_order=True)
        .unique(subset=['uhvdb_id'], keep='first', maintain_order=True)
        .select(keep_cols)
    )


def load_metadata(classify_tsv, completeness, metadata_df, clusters):
    classify_cols = [
        'uhvdb_id',
        'completeness_method',
        'contig_length',
        'proviral_length',
        'viral_genes',
    ]

    # Fresh classify values take precedence over stored metadata. Both sources
    # can contain duplicate uhvdb_id rows; joining without collapsing them
    # creates a per-ID cartesian product that inflates cluster metrics and
    # can change DTR vs AAI election outcomes.
    fresh_classify = dedupe_by_uhvdb_id(
        pl.read_csv(
            classify_tsv,
            separator='\t',
            ignore_errors=True,
            null_values=['NA'],
            columns=classify_cols,
        ).select(classify_cols)
    )
    meta_classify = dedupe_by_uhvdb_id(metadata_df.select(classify_cols))
    # Fresh first: unique(keep='first') preserves run values over metadata.
    classify_df = (
        pl.concat([fresh_classify, meta_classify], how='vertical_relaxed')
        .unique(subset=['uhvdb_id'], keep='first', maintain_order=True)
    )

    completeness_cols = ['uhvdb_id', 'aai_expected_length']
    fresh_completeness = dedupe_by_uhvdb_id(
        pl.read_csv(
            completeness,
            separator='\t',
            columns=completeness_cols,
            ignore_errors=True,
            null_values=['NA'],
        ).select(completeness_cols)
    )
    meta_completeness = dedupe_by_uhvdb_id(
        metadata_df.select(completeness_cols)
    )
    completeness_df = (
        pl.concat([fresh_completeness, meta_completeness], how='vertical_relaxed')
        .unique(subset=['uhvdb_id'], keep='first', maintain_order=True)
    )

    # Join cluster assignments instead of replace_strict on a large Python dict
    clusters_df = pl.DataFrame(
        {
            'uhvdb_id': list(clusters.keys()),
            'cluster_id': list(clusters.values()),
        }
    ).unique(subset=['uhvdb_id'], keep='first', maintain_order=True)

    mine_report = (
        classify_df
        .join(completeness_df, how='inner', on='uhvdb_id')
        .join(clusters_df, how='inner', on='uhvdb_id')
        .with_columns(
            [
                pl.when(pl.col('contig_length').is_not_null())
                .then(pl.col('contig_length'))
                .when(pl.col('proviral_length').is_not_null())
                .then(pl.col('proviral_length'))
                .alias('length')
                .cast(pl.Float64)
            ]
        )
    )

    return mine_report


def main(args=None):
    args = parse_args(args)

    # vClust Cluster Reps
    # 1. identify median length for each cluster
    # 2. Assign singletons as vOTU reps
    # 3. Assign longest DTRs as vOTU reps
    # 4. Assign linear genome with highest number of viral genes
    #    (tiebreaker: closest to expected AAI length)
    # 5. Output vOTU reps
    # 6. Output vClust vOTU cluster information

    # Read metadata once (classify fields, completeness, previous reps, old IDs)
    metadata_cols = [
        'uhvdb_id',
        'completeness_method',
        'contig_length',
        'proviral_length',
        'viral_genes',
        'aai_expected_length',
        'genomovar_rep',
        'species_rep',
    ]
    metadata_df = pl.read_csv(
        args.uhvdb_metadata,
        separator='\t',
        ignore_errors=True,
        null_values=['NA'],
        columns=metadata_cols,
    )

    # Cluster assignments: MCL members, then singletons for new + old IDs
    # (old IDs from metadata instead of scanning old.fna.gz headers)
    clusters, cluster_id = load_mcl_clusters(args.mcl)
    new_ids = read_fasta_ids(args.new_fna)
    old_ids = old_sequence_ids(metadata_df, args.cluster_level)
    clusters, _cluster_id = add_singleton_clusters(
        clusters, cluster_id, new_ids + old_ids
    )

    mine_report = load_metadata(
        args.tsv, args.completeness, metadata_df, clusters
    )

    # 1. calculate median length and size of each cluster
    # Count and median over unique sequences, not duplicated metadata rows.
    cluster_metrics = mine_report.group_by('cluster_id').agg(
        [
            pl.col('length').median().alias('median_length'),
            pl.col('viral_genes').max().alias('max_viral_genes'),
            pl.col('uhvdb_id').n_unique().alias('num_seqs'),
        ]
    )

    mine_report_metrics = mine_report.join(
        cluster_metrics, on='cluster_id', how='inner'
    )

    # 2. assign singletons as vOTU representatives
    singleton_cluster_ids = (
        cluster_metrics
        .filter(pl.col('num_seqs') == 1)
        .get_column('cluster_id')
    )

    cluster_reps = (
        mine_report
        .filter(pl.col('cluster_id').is_in(singleton_cluster_ids))
        .select(['uhvdb_id', 'cluster_id'])
        .unique(subset=['uhvdb_id', 'cluster_id'], maintain_order=True)
    )

    # 3. assign longest DTRs as vOTU representatives
    assigned_cluster_ids = cluster_reps.get_column('cluster_id')
    dtr_cluster_reps = (
        mine_report_metrics
        .filter(
            (pl.col('completeness_method').str.contains('DTR'))
            & (~pl.col('cluster_id').is_in(assigned_cluster_ids))
        )
        .sort(['length', 'viral_genes', 'uhvdb_id'], descending=[True, True, False])
        .group_by('cluster_id', maintain_order=True)
        .first()
        .select(['uhvdb_id', 'cluster_id'])
    )

    cluster_reps = pl.concat([cluster_reps, dtr_cluster_reps])

    # 4. Assign linear genome closest to expected AAI length with highest
    #    number of viral genes (sort keys unchanged from prior behaviour)
    assigned_cluster_ids = cluster_reps.get_column('cluster_id')
    linear_cluster_reps = (
        mine_report_metrics
        .filter(
            (~pl.col('cluster_id').is_in(assigned_cluster_ids))
            & (pl.col('viral_genes') == pl.col('max_viral_genes'))
        )
        .with_columns(
            [
                pl.col('aai_expected_length')
                .cast(pl.String)
                .str.replace('NA', pl.col('median_length'))
                .cast(pl.Float64)
                .alias('aai_expected_length'),
            ]
        )
        .with_columns(
            [
                (
                    abs(
                        pl.col('length').cast(pl.Float64)
                        - pl.col('aai_expected_length').cast(pl.Float64)
                    )
                ).alias('length_diff'),
            ]
        )
        .sort(['length_diff', 'uhvdb_id'], descending=[False, False])
        .group_by('cluster_id', maintain_order=True)
        .first()
        .select(['uhvdb_id', 'cluster_id'])
    )

    cluster_reps = pl.concat([cluster_reps, linear_cluster_reps])

    # 5. Split old vs new representatives
    # old = still a previous genomovar_rep/species_rep; new = not in that set
    if args.cluster_level in ('species', 'genomovars'):
        rep_col = (
            'species_rep' if args.cluster_level == 'species' else 'genomovar_rep'
        )
        prev_rep_ids = (
            metadata_df
            .get_column(rep_col)
            .drop_nulls()
        )
        old_rep_df = cluster_reps.filter(pl.col('uhvdb_id').is_in(prev_rep_ids))
        new_rep_df = cluster_reps.filter(~pl.col('uhvdb_id').is_in(prev_rep_ids))
        old_rep_df.select(['uhvdb_id']).write_csv(
            args.output_reps, separator='\t', include_header=False
        )
        new_rep_df.select(['uhvdb_id']).write_csv(
            args.output_new_reps, separator='\t', include_header=False
        )
    else:
        cluster_reps.select(['uhvdb_id']).write_csv(
            args.output_reps, separator='\t', include_header=False
        )
        cluster_reps.select(['uhvdb_id']).write_csv(
            args.output_new_reps, separator='\t', include_header=False
        )

    # 6. Output cluster information
    cluster_info = (
        mine_report_metrics
        .select(
            [
                'uhvdb_id',
                'cluster_id',
                'num_seqs',
                'length',
                'median_length',
                'aai_expected_length',
                'viral_genes',
                'max_viral_genes',
                'completeness_method',
            ]
        )
        .unique(subset=['uhvdb_id'], maintain_order=True)
        .join(cluster_reps, on='cluster_id', how='full', suffix='_rep')
        .drop('cluster_id_rep')
        .rename({'uhvdb_id_rep': f'{args.cluster_level}_rep'})
    )
    # Write plain TSV; module gzip step produces a valid .tsv.gz
    # (Polars write_csv into gzip.open('wt') yields an invalid hybrid file)
    out_path = args.cluster_info
    if str(out_path).endswith('.gz'):
        out_path = str(out_path)[:-3]
    cluster_info.write_csv(out_path, separator='\t')


if __name__ == "__main__":
    main()
