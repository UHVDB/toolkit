#!/usr/bin/env python3
# /// script
# dependencies = [
#   "pandas",
#   "openpyxl",
#   "requests",
#   "rich",
# ]
# ///

import os
import sys
import re
import time
import argparse
import requests
import pandas as pd
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TimeRemainingColumn, MofNCompleteColumn
from rich.table import Table
from rich.panel import Panel

# Initialize rich console
console = Console()

ICTV_VMR_URL = "https://ictv.global/vmr/current"

def download_vmr(url: str, dest_path: str) -> None:
    """Download the ICTV VMR Excel file from the given URL."""
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    with console.status("[bold blue]Downloading latest ICTV VMR Excel file...", spinner="dots"):
        response = requests.get(url, headers=headers, allow_redirects=True, stream=True)
        response.raise_for_status()
        
        # Save to destination
        with open(dest_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
    console.print(f"[green]✓[/green] Downloaded VMR file to [cyan]{dest_path}[/cyan]\n")

def parse_vmr(filepath: str, filters: dict) -> tuple[pd.DataFrame, list[str], dict]:
    """Parse the VMR Excel file, apply filters, and extract accession numbers."""
    with console.status("[bold blue]Parsing Excel file...", spinner="dots"):
        xls = pd.ExcelFile(filepath)
        
        # Find the main data sheet starting with VMR
        data_sheets = [s for s in xls.sheet_names if s.upper().startswith('VMR')]
        if data_sheets:
            sheet_name = data_sheets[0]
        else:
            # Fallback to index 1 (usually the second sheet)
            sheet_name = xls.sheet_names[1] if len(xls.sheet_names) > 1 else xls.sheet_names[0]
            
        df = pd.read_excel(filepath, sheet_name=sheet_name)
        
    console.print(f"[green]✓[/green] Loaded sheet: [bold cyan]{sheet_name}[/bold cyan] ({len(df):,} rows)")
    
    # Locate the accession column
    accession_col = None
    for col in df.columns:
        if 'genbank' in str(col).lower() and 'accession' in str(col).lower():
            accession_col = col
            break
            
    if not accession_col:
        raise ValueError("Could not find the GenBank accession column in the Excel file.")
        
    # Apply filters
    filtered_df = df.copy()
    filter_applied = False
    
    for key, value in filters.items():
        if value:
            # Map friendly key to actual column name in VMR
            col_map = {
                'family': 'Family',
                'genus': 'Genus',
                'species': 'Species',
                'genome': 'Genome',
                'host': 'Host source'
            }
            col_name = col_map.get(key)
            if col_name in filtered_df.columns:
                filter_applied = True
                filtered_df = filtered_df[filtered_df[col_name].astype(str).str.contains(value, case=False, na=False)]
                
    if filter_applied:
        console.print(f"[green]✓[/green] Applied filters. Matching rows: [bold cyan]{len(filtered_df):,}[/bold cyan] / {len(df):,}")
        
    # Extract accessions
    accession_pattern = re.compile(r'\b([A-Z]{1,8}_?\d{5,10}(?:\.\d+)?)\b', re.IGNORECASE)
    
    accessions_list = []
    accession_to_metadata = {}
    
    for _, row in filtered_df.iterrows():
        val = row[accession_col]
        if pd.isna(val):
            continue
            
        val_str = str(val).strip()
        matches = accession_pattern.findall(val_str)
        
        for m in matches:
            acc = m.upper()
            if acc not in accession_to_metadata:
                metadata = {
                    'realm': str(row.get('Realm', 'N/A')).strip(),
                    'family': str(row.get('Family', 'N/A')).strip(),
                    'genus': str(row.get('Genus', 'N/A')).strip(),
                    'species': str(row.get('Species', 'N/A')).strip(),
                    'virus_name': str(row.get('Virus name(s)', 'N/A')).strip(),
                    'host': str(row.get('Host source', 'N/A')).strip(),
                }
                # Clean up nan or empty strings in metadata
                for k, v in metadata.items():
                    if v.lower() == 'nan' or not v:
                        metadata[k] = 'N/A'
                        
                accessions_list.append(acc)
                accession_to_metadata[acc] = metadata

    return filtered_df, accessions_list, accession_to_metadata

def fetch_batch_with_retry(batch: list[str], rettype: str = "fasta", api_key: str = None, retries: int = 3, base_delay: float = 1.0) -> str:
    """Fetch a batch of accessions from NCBI efetch with retries and exponential backoff."""
    url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"
    data = {
        "db": "nuccore",
        "id": ",".join(batch),
        "rettype": rettype,
        "retmode": "text"
    }
    if api_key:
        data["api_key"] = api_key
        
    for attempt in range(retries + 1):
        try:
            response = requests.post(url, data=data, timeout=90)
            if response.status_code == 200:
                return response.text
            elif response.status_code == 429:
                # Rate limit exceeded
                if attempt == retries:
                    raise Exception("Rate limit exceeded (HTTP 429) after maximum retries.")
                sleep_time = base_delay * (2 ** attempt)
                console.print(f"[warning]Rate limited (HTTP 429). Retrying in {sleep_time:.1f}s...[/warning]")
                time.sleep(sleep_time)
            else:
                if attempt == retries:
                    raise Exception(f"HTTP Error {response.status_code} from NCBI.")
                sleep_time = base_delay * (2 ** attempt)
                console.print(f"[warning]HTTP Error {response.status_code}. Retrying in {sleep_time:.1f}s...[/warning]")
                time.sleep(sleep_time)
        except (requests.exceptions.RequestException, Exception) as e:
            if attempt == retries:
                raise e
            sleep_time = base_delay * (2 ** attempt)
            console.print(f"[warning]Request failed ({str(e)}). Retrying in {sleep_time:.1f}s...[/warning]")
            time.sleep(sleep_time)
            
    raise Exception("Failed to fetch batch.")

def parse_fasta_records(fasta_text: str) -> list[tuple[str, str]]:
    """Parse raw FASTA text into a list of (header, sequence) tuples."""
    records = []
    current_header = None
    current_seq = []
    for line in fasta_text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith('>'):
            if current_header:
                records.append((current_header, ''.join(current_seq)))
                current_seq = []
            current_header = line[1:]
        else:
            current_seq.append(line)
    if current_header:
        records.append((current_header, ''.join(current_seq)))
    return records

def get_parent_accession(header_str: str) -> str:
    """Extract the parent accession number from a FASTA header.
    Handles standard, WGS, and CDS (e.g. lcl|NC_001234.1_cds_...) headers."""
    # Remove leading '>' if present
    if header_str.startswith('>'):
        header_str = header_str[1:]
    
    # If it's a local database ID from NCBI (starts with lcl|)
    if "lcl|" in header_str:
        part = header_str.split("lcl|")[1].split()[0]
        # E.g. "MH447526.1_cds_AXQ00083.1_1" or "MH447526.1_prot_AXQ00083.1_1"
        for sep in ["_cds_", "_prot_"]:
            if sep in part:
                return part.split(sep)[0].split('.')[0].upper()
                
    # Fallback: search for the first match that looks like an accession number
    match = re.search(r'\b([A-Z]{1,8}_?\d{5,10}(?:\.\d+)?)\b', header_str, re.IGNORECASE)
    if match:
        return match.group(1).split('.')[0].upper()
        
    # Last resort: just take the first word
    return header_str.split()[0].split('.')[0].upper()


def write_fasta_record(file_obj, header: str, seq: str) -> None:
    """Write a single FASTA record to a file, wrapping the sequence at 70 characters."""
    file_obj.write(f">{header}\n")
    for i in range(0, len(seq), 70):
        file_obj.write(seq[i:i+70] + "\n")

def main():
    parser = argparse.ArgumentParser(
        description="ICTV VMR Sequence Downloader - Rapidly download all or filtered sequences from an ICTV VMR Excel file using NCBI E-utilities.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "input_file",
        nargs="?",
        help="Path or URL to the ICTV VMR Excel file. If omitted, the latest VMR file will be downloaded automatically."
    )
    parser.add_argument(
        "-o", "--output",
        help="Path to the output multi-FASTA file. Cannot be used with --dir."
    )
    parser.add_argument(
        "-d", "--dir",
        help="Directory to save individual FASTA files (one per accession). Cannot be used with --output."
    )
    parser.add_argument(
        "-b", "--batch-size",
        type=int,
        default=200,
        help="Number of accessions to fetch in each NCBI request."
    )
    parser.add_argument(
        "-k", "--api-key",
        help="NCBI API key. If not provided, will look for the NCBI_API_KEY env var."
    )
    parser.add_argument(
        "-t", "--delay",
        type=float,
        help="Delay in seconds between NCBI requests (default: 0.35s without API key, 0.1s with API key)."
    )
    parser.add_argument(
        "--enrich-headers",
        action="store_true",
        help="Rewrite FASTA headers to include VMR taxonomy metadata."
    )
    parser.add_argument(
        "--type",
        choices=["genomic", "cds-na", "cds-aa"],
        default="genomic",
        help="Type of sequence to download: 'genomic' for full genome, 'cds-na' for coding region nucleotide sequences, 'cds-aa' for coding region translated amino acids."
    )
    parser.add_argument(
        "--family",
        help="Filter by family (case-insensitive substring match)."
    )
    parser.add_argument(
        "--genus",
        help="Filter by genus (case-insensitive substring match)."
    )
    parser.add_argument(
        "--species",
        help="Filter by species (case-insensitive substring match)."
    )
    parser.add_argument(
        "--genome",
        help="Filter by genome composition (case-insensitive substring match)."
    )
    parser.add_argument(
        "--host",
        help="Filter by host source (case-insensitive substring match)."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Parse the VMR spreadsheet and display a summary of accessions, but do not download."
    )
    parser.add_argument(
        "--skip-errors",
        action="store_true",
        help="Skip failed batches and continue downloading."
    )
    
    args = parser.parse_args()
    
    # Enforce mutual exclusivity of output/dir
    if args.output and args.dir:
        console.print("[bold red]Error:[/bold red] Cannot specify both --output and --dir. Choose one.", style="red")
        sys.exit(1)
        
    # Default output file if not in dir mode and not dry run
    if not args.dry_run and not args.output and not args.dir:
        args.output = "ictv_sequences.fasta"
        
    # Resolve API Key
    api_key = args.api_key or os.environ.get("NCBI_API_KEY")
    
    # Determine delay
    if args.delay is not None:
        delay = args.delay
    else:
        delay = 0.1 if api_key else 0.35
        
    # Map sequence type to NCBI rettype
    type_to_rettype = {
        "genomic": "fasta",
        "cds-na": "fasta_cds_na",
        "cds-aa": "fasta_cds_aa"
    }
    rettype = type_to_rettype[args.type]
        
    # Resolve input file
    input_file = args.input_file
    temp_downloaded = False
    if not input_file:
        input_file = "vmr_current.xlsx"
        if not os.path.exists(input_file):
            try:
                download_vmr(ICTV_VMR_URL, input_file)
                temp_downloaded = True
            except Exception as e:
                console.print(f"[bold red]Error downloading VMR file from ICTV:[/bold red] {e}")
                sys.exit(1)
    elif input_file.startswith("http://") or input_file.startswith("https://"):
        url = input_file
        input_file = "vmr_downloaded.xlsx"
        try:
            download_vmr(url, input_file)
            temp_downloaded = True
        except Exception as e:
            console.print(f"[bold red]Error downloading VMR file from {url}:[/bold red] {e}")
            sys.exit(1)
            
    # Gather filters
    filters = {
        'family': args.family,
        'genus': args.genus,
        'species': args.species,
        'genome': args.genome,
        'host': args.host
    }
    
    try:
        filtered_df, accessions, metadata_map = parse_vmr(input_file, filters)
    except Exception as e:
        console.print(f"[bold red]Error parsing VMR file:[/bold red] {e}")
        if temp_downloaded and os.path.exists(input_file):
            os.remove(input_file)
        sys.exit(1)
        
    total_accessions = len(accessions)
    
    if total_accessions == 0:
        console.print("[yellow]No accessions match the specified filters.[/yellow]")
        if temp_downloaded and os.path.exists(input_file):
            os.remove(input_file)
        sys.exit(0)
        
    # Display Summary Table
    table = Table(title="Download Job Summary")
    table.add_column("Property", style="cyan")
    table.add_column("Value", style="magenta")
    
    table.add_row("Total Accessions Found", f"{total_accessions:,}")
    table.add_row("Batch Size", str(args.batch_size))
    table.add_row("Number of Batches", str((total_accessions + args.batch_size - 1) // args.batch_size))
    table.add_row("NCBI API Key Present", "Yes (10 req/s limit)" if api_key else "No (3 req/s limit)")
    table.add_row("Delay Between Requests", f"{delay}s")
    
    if args.output:
        table.add_row("Output Type", "Single Multi-FASTA File")
        table.add_row("Output Path", args.output)
    elif args.dir:
        table.add_row("Output Type", "Directory of Individual Files")
        table.add_row("Output Path", args.dir)
    else:
        table.add_row("Output Type", "Dry-run (No output)")
        
    table.add_row("Sequence Type", args.type)
    table.add_row("Enrich Headers with Taxonomy", "Yes" if args.enrich_headers else "No")
    
    console.print(table)
    console.print()
    
    if args.dry_run:
        console.print("[bold green]Dry-run complete. No sequences were downloaded.[/bold green]")
        if temp_downloaded and os.path.exists(input_file):
            os.remove(input_file)
        sys.exit(0)
        
    # Prepare output
    if args.dir:
        os.makedirs(args.dir, exist_ok=True)
        out_file = None
    else:
        try:
            out_file = open(args.output, 'w', encoding='utf-8')
        except Exception as e:
            console.print(f"[bold red]Error opening output file {args.output}:[/bold red] {e}")
            sys.exit(1)
            
    # Chunk accessions into batches
    batches = [accessions[i:i + args.batch_size] for i in range(0, total_accessions, args.batch_size)]
    
    downloaded_count = 0
    failed_accessions = []
    
    # Progress bars using rich
    last_req_time = 0.0
    
    with Progress(
        SpinnerColumn(),
        TextColumn("[progress.description]{task.description}"),
        BarColumn(),
        MofNCompleteColumn(),
        TimeRemainingColumn(),
        console=console
    ) as progress:
        
        task = progress.add_task("[green]Downloading sequences...", total=len(batches))
        
        for batch_num, batch in enumerate(batches, 1):
            # Enforce rate limit delay
            elapsed = time.time() - last_req_time
            if elapsed < delay:
                time.sleep(delay - elapsed)
                
            last_req_time = time.time()
            
            try:
                # Fetch batch from NCBI
                fasta_text = fetch_batch_with_retry(batch, rettype=rettype, api_key=api_key)
                
                # Parse returned records
                records = parse_fasta_records(fasta_text)
                downloaded_in_batch = set()
                
                # Group records by parent accession to handle multiple CDS per accession properly
                grouped_records = {}
                for orig_header, seq in records:
                    parent_acc = get_parent_accession(orig_header)
                    downloaded_in_batch.add(parent_acc)
                    
                    if parent_acc not in grouped_records:
                        grouped_records[parent_acc] = []
                    grouped_records[parent_acc].append((orig_header, seq))
                    
                # Now write the grouped records
                for parent_acc, recs in grouped_records.items():
                    if args.enrich_headers:
                        meta = metadata_map.get(parent_acc)
                        if meta:
                            enriched_recs = []
                            for orig_header, seq in recs:
                                header = f"{orig_header} | Virus Name: {meta['virus_name']} | Species: {meta['species']} | Genus: {meta['genus']} | Family: {meta['family']} | Realm: {meta['realm']} | Host: {meta['host']}"
                                enriched_recs.append((header, seq))
                            recs = enriched_recs
                            
                    if args.dir:
                        file_path = os.path.join(args.dir, f"{parent_acc}.fasta")
                        with open(file_path, 'w', encoding='utf-8') as f:
                            for header, seq in recs:
                                write_fasta_record(f, header, seq)
                    else:
                        for header, seq in recs:
                            write_fasta_record(out_file, header, seq)
                            
                    downloaded_count += len(recs)
                    
                # Identify any accessions in the batch that failed to return a sequence
                for acc in batch:
                    if acc not in downloaded_in_batch:
                        failed_accessions.append(acc)
                        
            except Exception as e:
                console.print(f"\n[bold red]Error in batch {batch_num}/{len(batches)}:[/bold red] {e}")
                if args.skip_errors:
                    failed_accessions.extend(batch)
                else:
                    if out_file:
                        out_file.close()
                    sys.exit(1)
                    
            progress.advance(task)
            
    if out_file:
        out_file.close()
        
    # Clean up downloaded VMR file if it was temporary
    if temp_downloaded and os.path.exists(input_file):
        os.remove(input_file)
        
    # Print Final Summary
    console.print(Panel(
        f"[bold green]Download Complete![/bold green]\n\n"
        f"  • Total expected accessions: [bold]{total_accessions:,}[/bold]\n"
        f"  • Successfully downloaded: [bold green]{downloaded_count:,}[/bold green]\n"
        f"  • Failed/Missing accessions: [bold red]{len(failed_accessions):,}[/bold red]",
        title="Execution Summary",
        expand=False
    ))
    
    if failed_accessions:
        console.print("\n[bold yellow]The following accessions failed to download (may be invalid, obsolete, or restricted):[/bold yellow]")
        for f_acc in failed_accessions[:50]:
            console.print(f"  - {f_acc}")
        if len(failed_accessions) > 50:
            console.print(f"  ... and {len(failed_accessions) - 50} more (see full list in stdout if needed).")

if __name__ == "__main__":
    main()
