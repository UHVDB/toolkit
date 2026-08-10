#!/usr/bin/env python

import argparse
import re
import sys

import fastexcel
import polars as pl


ACCESSION_RE = re.compile(r"\b([A-Z]{1,8}_?\d{5,10}(?:\.\d+)?)\b", re.IGNORECASE)


def parse_args(args=None):
    description = "Compile UHVDB taxonomy data."
    epilog = "Example usage: python uhvdb_taxonomy.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-t",
        "--classify_tsv",
        help="Path to TSV file output by UHVDB's classify subworkflow.",
    )
    parser.add_argument(
        "-n",
        "--normscore_tsv",
        help="Path to TSV file output by normscore.",
    )
    parser.add_argument(
        "-v",
        "--vmr_url",
        help="Path to VMR URL.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output TSV file containing taxonomy information for each virus.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def _vmr_sheet_name(vmr_path):
    sheet_names = fastexcel.read_excel(vmr_path).sheet_names
    vmr_sheets = [s for s in sheet_names if s.upper().startswith('VMR')]
    if vmr_sheets:
        return vmr_sheets[0]
    return sheet_names[1] if len(sheet_names) > 1 else sheet_names[0]


def _genbank_accession_column(columns):
    for col in columns:
        col_l = str(col).lower()
        if 'genbank' in col_l and 'accession' in col_l:
            return col
    raise ValueError("Could not find the GenBank accession column in the VMR Excel file.")


def _vmr_accession_map(vmr_path, sheet_name):
    """Map GenBank accessions from the VMR to ICTV taxonomy ranks."""
    vmr = pl.read_excel(vmr_path, sheet_name=sheet_name)
    acc_col = _genbank_accession_column(vmr.columns)

    rows = []
    for species, genus, family, order, cls, raw in vmr.select(
        ['Species', 'Genus', 'Family', 'Order', 'Class', acc_col]
    ).iter_rows():
        if raw is None:
            continue
        for match in ACCESSION_RE.findall(str(raw)):
            rows.append(
                (
                    match.split('.')[0].upper(),
                    species,
                    genus,
                    family,
                    order,
                    cls,
                )
            )

    if not rows:
        return pl.DataFrame(
            schema={
                'accession': pl.Utf8,
                'Species': pl.Utf8,
                'Genus': pl.Utf8,
                'Family': pl.Utf8,
                'Order': pl.Utf8,
                'Class': pl.Utf8,
            }
        )

    return (
        pl.DataFrame(
            rows,
            schema=['accession', 'Species', 'Genus', 'Family', 'Order', 'Class'],
            orient='row',
        )
        .unique(subset=['accession'], keep='first')
    )


def main(args=None):
    args = parse_args(args)

    # load classify tsv
    # Map outdated geNomad class names to current ICTV VMR names so the Class join works.
    classify = (
        pl.read_csv(args.classify_tsv, separator='\t', null_values=["NA"], columns=['uhvdb_id', 'taxonomy'])
            .with_columns([
                pl.when(pl.col('taxonomy').str.contains('Anelloviridae')).then(pl.lit('Cardeaviricetes'))
                    .when(pl.col('taxonomy').str.contains('Malgrandaviricetes')).then(pl.lit('Microviricetes'))
                    .when(~pl.col('taxonomy').str.contains('viricetes')).then(pl.lit('No class'))
                    .when(pl.col('taxonomy').str.contains('viricetes')).then(pl.col('taxonomy').str.split(';').list.get(4, null_on_oob=True))
                    .alias('Class')
            ])
    )

    # #region agent log
    _dbg_path = "/mmfs1/gscratch/pedslabs_hoffman/carsonjm/CFPhageome/repos/UHVDB/toolkit2/.cursor/debug-0661f2.log"
    def _dbg(hypothesis_id, location, message, data, run_id="post-fix-class"):
        import json, time
        with open(_dbg_path, "a") as _f:
            _f.write(json.dumps({
                "sessionId": "0661f2",
                "runId": run_id,
                "hypothesisId": hypothesis_id,
                "location": location,
                "message": message,
                "data": data,
                "timestamp": int(time.time() * 1000),
            }) + "\n")
    # #endregion

    # load normscore tsv; refs are genome IDs (ACCESSION[.version] after pyrodigal) or legacy lcl| protein IDs
    normscore = (
        pl.read_csv(args.normscore_tsv, separator='\t', null_values=["NA"], has_header=False, new_columns=['uhvdb_id', 'ref', 'normscore'])
            .with_columns([
                pl.when(pl.col('ref').str.starts_with('lcl|'))
                    .then(
                        pl.col('ref')
                            .str.extract(r'lcl\|([A-Za-z0-9_]+)', 1)
                            .str.split('.')
                            .list.get(0)
                            .str.to_uppercase()
                    )
                    .otherwise(
                        pl.col('ref')
                            .str.split('.')
                            .list.get(0)
                            .str.to_uppercase()
                    )
                    .alias('accession')
            ])
            .sort('normscore', descending=True)
            .unique(['uhvdb_id'], maintain_order=True)
    )

    sheet_name = _vmr_sheet_name(args.vmr_url)
    msl = _vmr_accession_map(args.vmr_url, sheet_name)

    # join normscore with VMR via GenBank accession
    ictv_class = (
        normscore
            .join(msl, on='accession', how='left')
            .drop('accession')
    )

    # retain ICTV annotation only when Class agrees with classify
    result = (
        classify
            .join(ictv_class, on=['uhvdb_id', 'Class'], how='left')
    )

    # #region agent log
    _dbg("F", "uhvdb_taxonomy.py:result", "Ref population after Malgrandaviricetes synonym", {
        "result_rows": result.height,
        "ref_nonnull": result.filter(pl.col('ref').is_not_null()).height,
        "microviricetes_with_ref": result.filter((pl.col('Class') == 'Microviricetes') & pl.col('ref').is_not_null()).height,
        "class_counts_with_ref": result.filter(pl.col('ref').is_not_null())['Class'].value_counts().head(10).to_dicts(),
    })
    # #endregion

    result.write_csv(args.output, separator='\t')


if __name__ == "__main__":
    sys.exit(main())
