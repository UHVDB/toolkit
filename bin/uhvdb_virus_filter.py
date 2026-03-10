#!/usr/bin/env python

import argparse
import gzip
import sys

from Bio import SeqIO
import polars as pl


def parse_args(args=None):
    description = "Perform UHVDB virus filtering and confidence assignment."
    epilog = "Example usage: python uhvdb_virus_filter.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-f",
        "--fasta",
        help="Path to nucleotide fasta created by combining provirus/virus fastas output by CheckV.",
    )
    parser.add_argument(
        "-v",
        "--virus_summary",
        help="Path to virus summary file output by geNomad.",
    )
    parser.add_argument(
        "-g",
        "--genes",
        help="Path to genes.tsv file output by geNomad.",
    )
    parser.add_argument(
        "-q",
        "--quality_summary",
        help="Path to quality_summary.tsv file output by CheckV.",
    )
    parser.add_argument(
        "-r",
        "--viralverify",
        help="Path to CSV file output by viralverify.",
    )
    parser.add_argument(
        "-d",
        "--dtr_sequences",
        help="Path to TXT file containing DTR sequences that were trimmed before being run through pipeline.",
    )
    parser.add_argument(
        "-ot",
        "--output_tsv",
        help="Output TSV file containing combined data and UHVDB virus classification/confidence.",
    )
    parser.add_argument(
        "-of",
        "--output_fasta",
        help="Output FASTA file containing sequences classified uncertain or confident.",
    )
    parser.add_argument(
        "-s",
        "--source_db",
        help="Name of source database.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


# Define accessions for conjugation and zot gene
conj_genes = [
    "K03194", "K03195", "K03196", "K03197",
    "K03198", "K03199", "K03200", "K03201",
    "K03202", "K03203", "K03204", "K03205",
    "K07467", "K12056", "K12057", "K12058",
    "K12059", "K12060", "K12061", "K12062",
    "K12063", "K12064", "K12065", "K12066",
    "K12067", "K12068", "K12069", "K12070",
    "K12071", "K12072", "K18433", "K18434",
    "PF01076", "PF03389", "PF03432", "PF04837",
    "PF04899", "PF05261", "PF05309", "PF05509",
    "PF05513", "PF05713", "PF06986", "PF07042",
    "PF09673", "PF09677", "PF10412", "PF10623",
    "PF10624", "PF11130", "PF12477", "PF17413",
    "PF17511", "PF18340", "PF19456", "PF19514"
]

zot_gene = "PF05707"

def extract_family(value):
    if value is None:
        return ""
    parts = value.split(';')
    if len(parts) > 1:
        return parts[-1].strip()
    return ""


def main(args=None):
    args = parse_args(args)

    if args.source_db == "":
        args.source_db = "no_source_db"

    # load files
    virus_summary = pl.read_csv(
        args.virus_summary, separator='\t',
        columns=[
            "seq_name", "topology", "coordinates", "n_genes", "genetic_code",
            "virus_score", "fdr", "n_hallmarks", "marker_enrichment", "taxonomy"
        ]
    )
    genomad_genes = pl.read_csv(
        args.genes, separator='\t', ignore_errors=True,
        columns=[
            "gene", "annotation_accessions", "plasmid_hallmark", "taxname", "marker"
        ]
    )

    if args.dtr_sequences != '':
        dtr_seq_set = set(pl.read_csv(args.dtr_sequences, has_header=False, new_columns=['seq_name'])['seq_name'])
    else:
        dtr_seq_set = set()
    
    quality_summary = (
        pl.read_csv(
            args.quality_summary, separator='\t', ignore_errors=True,
            columns=[
                'contig_id', 'contig_length', 'proviral_length', 'viral_genes', 'host_genes', 'provirus',
                'completeness', 'completeness_method', 'kmer_freq', 'warnings'
            ]
        )
        .with_columns([
            pl.when((pl.col('contig_id').is_in(dtr_seq_set)) & (pl.col('completeness') >= 80))
                .then(pl.lit(100))
                .otherwise(pl.col('completeness'))
                .alias('completeness'),
            pl.when((pl.col('contig_id').is_in(dtr_seq_set)) & (pl.col('completeness') >= 80))
                .then(pl.lit('DTR'))
                .otherwise(pl.col('completeness_method'))
                .alias('completeness_method')
        ])
    )
    viralverify = pl.read_csv(
        args.viralverify, separator=',', ignore_errors=True,
        columns=[
            "Contig name", "Prediction", "Score", "Pfam hits"
        ]
    )

    # print counts for each step
    print("Number of sequences output by geNomad:", f'{virus_summary.shape[0]:_}')
    print("Number of sequences passing coarse geNomad filters:", f'{quality_summary.shape[0]:_}')
    print("Number of sequences passing coarse CheckV filters:", f'{viralverify.shape[0]:_}')

    # count genomad marker duplicity
    genomad_total_markers = (
        genomad_genes
            .with_columns([
                pl.col('gene').str.replace(r"_[^_]*$", "").alias('genome')
            ])
            .group_by('genome')
            .agg([pl.col('marker').count().alias('total_markers')])
    )

    genomad_duplicated_markers = (
        genomad_genes
            .with_columns([
                pl.col('gene').str.replace(r"_[^_]*$", "").alias('genome')
            ])
            .group_by(['genome', 'marker'])
            .agg([pl.col('marker').count().alias('n_marker')])
            .filter(pl.col('n_marker') > 1)
            .group_by('genome')
            .agg([pl.col('n_marker').count().alias('n_dup_markers')])
    )

    genomad_marker_duplicity = (
        genomad_total_markers
            .join(genomad_duplicated_markers, on='genome', how='left')
            .with_columns([
                pl.col('n_dup_markers').fill_null(0).cast(pl.Int64),
                (1 + (pl.col('n_dup_markers') / pl.col('total_markers'))).alias('marker_duplicity')
            ])
    )

    # identify plasmid/conjugation genes in genomad genes
    genomad_nonviral_gene_counts = (
        genomad_genes
            .with_columns([
                pl.col('gene').str.replace(r"_[^_]*$", "").alias('genome'),
                pl.col('annotation_accessions').str.split(';')
            ])
            .with_columns([
                (pl.col("annotation_accessions").list.set_intersection(conj_genes).list.len() != 0).alias('conj_gene'),
                (pl.col("annotation_accessions").list.contains(zot_gene)).alias('zot_gene'),
                (pl.col("taxname").str.contains('Inoviridae').alias('inoviridae_marker_gene'))
            ])
            .group_by('genome')
            .agg([
                pl.col('plasmid_hallmark').sum().alias('plasmid_hallmarks'),
                pl.col('conj_gene').sum().alias('conj_genes'),
                pl.col('zot_gene').sum().alias('zot_genes'),
                pl.col('inoviridae_marker_gene').sum().alias('inoviridae_marker_genes'),
            ])
            .join(genomad_marker_duplicity, on='genome', how='left')
    )

    # join dataframes
    joined = (
        virus_summary
            .with_columns([
                pl.col('seq_name').str.replace(r"\|provirus[^|provirus]*$", "").alias('genome')
            ])
            .join(genomad_nonviral_gene_counts, on='genome', how='left')
            .join(quality_summary, left_on='seq_name', right_on='contig_id', how='left')
            .join(viralverify, left_on='seq_name', right_on='Contig name', how='left')
            .with_columns([
                pl.col('taxonomy').map_elements(extract_family, return_dtype=pl.String).alias('ictv_family'),
                pl.col('Score').cast(pl.String).str.replace('-', '0').cast(pl.Float64).alias('Score')
            ])
    )

    # assign points to each sequence based on UHVDB criteria
    joined_w_scores = (
        joined
            .filter((~pl.col('warnings').str.contains('>1 viral region')) | (pl.col('warnings').is_null()))
            # assign points based on various criteria
            .with_columns([
                pl.when(pl.col('virus_score') >= 0.95)
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('genomad_virus_score_95'),
                pl.when((pl.col('Prediction') == 'Virus') & (pl.col('Score') >= 15))
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('viralverify_virus_score_15'),
                pl.when((pl.col('n_hallmarks') >= 3) | ((pl.col('viral_genes') >= 3) & (pl.col('viral_genes')/pl.col('host_genes') >= 3)))
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('virus_hallmarks_gt_3'),
                pl.when(pl.col('ictv_family')!= '')
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('ictv_known_family'),
                pl.when(pl.col('zot_genes') > 0)
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('zot_gene'),
                pl.when(pl.col('inoviridae_marker_genes') >= 5)
                    .then(pl.lit(1))
                    .otherwise(pl.lit(0))
                    .alias('inoviridae_marker_genes_gt_5'),
                pl.when((pl.col('Prediction') == 'Chromosome') | (pl.col('Prediction') == 'Plasmid'))
                    .then(pl.lit(-1))
                    .otherwise(pl.lit(0))
                    .alias('viralverify_chromosome_plasmid'),
                pl.when((pl.col('host_genes') >= 2) & (pl.col('host_genes')/pl.col('viral_genes') > 1))
                    .then(pl.lit(-1))
                    .otherwise(pl.lit(0))
                    .alias('checkv_host_genes_gt_2'),
                pl.when(pl.col('plasmid_hallmarks') > 0)
                    .then(pl.lit(-1))
                    .otherwise(pl.lit(0))
                    .alias('plasmid_hallmarks_gt_0'),
                pl.when(pl.col('conj_genes') > 0)
                    .then(pl.lit(-1))
                    .otherwise(pl.lit(0))
                    .alias('conj_genes_gt_0'),
                pl.when(pl.col('marker_duplicity') >= 1.2)
                    .then(pl.lit(-7))
                    .otherwise(pl.lit(0))
                    .alias('marker_duplicity_penalty')
            ])
            # sum the scores to get a final classification
            .with_columns([pl.sum_horizontal([
                pl.col('genomad_virus_score_95'),
                pl.col('viralverify_virus_score_15'),
                pl.col('virus_hallmarks_gt_3'),
                pl.col('ictv_known_family'),
                pl.col('zot_gene'),
                pl.col('inoviridae_marker_genes_gt_5'),
                pl.col('viralverify_chromosome_plasmid'),
                pl.col('plasmid_hallmarks_gt_0'),
                pl.col('conj_genes_gt_0'),
                pl.col('marker_duplicity_penalty'),
                pl.col('checkv_host_genes_gt_2')
            ]).alias('viral_score_sum'),
            ])
            .with_columns([
                pl.when(pl.col('viral_score_sum') >= 2)
                    .then(pl.lit('confident'))
                    .when(pl.col('viral_score_sum') >= 0)
                    .then(pl.lit('uncertain'))
                    .otherwise(pl.lit('non-viral'))
                    .alias('uhvdb_virus_classification')
            ])
            .with_columns([
                pl.lit(args.source_db).alias('source_db')
            ])
    )

    print("Number of sequences passing coarse CheckV filters:", f'{viralverify.shape[0]:_}')

    # write tsv output
    joined_w_scores.write_csv(args.output_tsv, separator='\t')

    # extract sequences classified as uncertain or confident
    uncertain_confident = set(
        joined_w_scores
            .filter(pl.col('uhvdb_virus_classification').is_in(['uncertain', 'confident']))
            ['seq_name']
    )
    print("Number of sequences passing UHVDB filters:", f'{len(uncertain_confident):_}')

    # write output FASTA file
    viral_seqs = []
    already_added = set()

    with gzip.open(args.fasta, 'rt') as fasta_gunzipped:
        for record in SeqIO.parse(fasta_gunzipped, "fasta"):
            if record.id in uncertain_confident and record.id not in already_added:
                viral_seqs.append(record)
                already_added.add(record.id)
            else:
                continue

    SeqIO.write(viral_seqs, args.output_fasta, "fasta")

if __name__ == "__main__":
    sys.exit(main())
