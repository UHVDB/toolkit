#!/usr/bin/env python3
"""A tool to predict prokaryotic hosts for phage (meta)genomic sequences. 
PHIST links viruses to hosts based on the number of k-mers shared between 
their sequences.

Copyright (C) 2021 A. Zielezinski, S. Deorowicz, and A. Gudys
https://github.com/refresh-bio/PHIST
"""

from __future__ import annotations
import argparse
import multiprocessing
import platform
from pathlib import Path
import subprocess
import sys

__version__ = '1.2.1'


def get_parser() -> argparse.ArgumentParser:
    desc = f'PHIST predicts hosts from phage (meta)genomic data'
    p = argparse.ArgumentParser(description=desc)
    p.add_argument('virus_db',
                   help='Input kmer-db file built from virus FASTA files')
    p.add_argument('host_dir', metavar='host_dir',
                   help='Input directory w/ host FASTA files (plain or gzip)')
    p.add_argument('out_dir', metavar='out_dir', nargs='+',
                   help='Output directory (will be created if it does not exist)')
    p.add_argument('-k', dest='k', type=int,
                   default=25, help='k-mer length [default =  %(default)s]')
    p.add_argument('-t', dest='num_threads', type=int,
                   default=multiprocessing.cpu_count(),
                   help='Number of threads [default = %(default)s]')
    p.add_argument('--keep_temp', action="store_true",
                   help='Keep temporary kmer-db files [%(default)s]')
    p.add_argument('--version', action='version',
                   version=__version__,
                   help="Show tool's version number and exit")

    # Display help if the script is run without arguments.
    if len(sys.argv[1:]) == 0:
        p.print_help()
        p.exit()
    return p


def validate_args(parser: argparse.ArgumentParser) -> argparse.Namespace:
    """Validates arguments provided by the user.

    Returns:
        Arguments provided by the users.
    Raises:
        argparse.ArgumentParser.error if arguments are invalid.
    """
    args = parser.parse_args()
    
    # Validate k-mer length
    if args.k < 3 or args.k > 30:
        parser.error(f'K-mer length should be in range 3-30.')

    # Validate virus input
    virus_db = Path(args.virus_db)
    if not virus_db.exists():
        parser.error(f'Virus kmer-db does not exist: {virus_db}')

    # Validate host input
    hdir_path = Path(args.host_dir)
    if not hdir_path.exists() or not hdir_path.is_dir():
        parser.error(f'Input host directory does not exist: {hdir_path}')

    args.virus_db = virus_db
    args.hdir_path = hdir_path

    # Validate output files
    if len(args.out_dir) > 1:
        args.outtable_path = Path(args.out_dir[0])
        args.outpred_path = Path(args.out_dir[1])
        args.out_dir = args.outtable_path.parent
    else:
        args.out_dir = Path(args.out_dir[0])
        args.outtable_path = args.out_dir / 'common_kmers.csv'
        args.outpred_path = args.out_dir / 'predictions.csv'
    return args


if __name__ == '__main__':
    
    PHIST_DIR = Path(__file__).resolve().parent

    util_exec = PHIST_DIR.joinpath('phist')

    parser = get_parser()
    args = validate_args(parser)

    print(
        f'PHIST  v{__version__}\n',
        'A. Zielezinski, S. Deorowicz, A. Gudys (c) 2021\n\n')

    virus_db = args.virus_db
    hdir_path = args.hdir_path
    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    # Paths to temp files
    hlst_path = out_dir / 'host.list'
    db_path = out_dir / 'virus.kdb'

    # Create host.list.
    with open(hlst_path, 'w') as oh:
        for f in sorted(hdir_path.rglob('*')):
            if f.is_file():
                oh.write(f"{f}\n")
        oh.close()

    # Kmer-db new2all
    cmd = [
        f'kmer-db',
        'new2all',
        '-sparse',
        '-min',
        'num-kmers:20',
        '-t',
        f'{args.num_threads}',
        f'{virus_db}',
        f'{hlst_path}',
        f'{args.outtable_path}',
    ]
    subprocess.run(cmd)

    # Remove temp files.
    if not args.keep_temp:
        hlst_path.unlink()
        db_path.unlink()
    
    # Postprocessing
    cmd = [
        f'{util_exec}',
        f'{args.outtable_path}',
        f'{args.outpred_path}',
    ]
    subprocess.run(cmd)
