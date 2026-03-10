#!/usr/bin/env python3

import rich_click as click
click.rich_click.USE_RICH_MARKUP = True
import functools
import logging
from rich.logging import RichHandler

################################################
## Prepare the logger
################################################
logger = logging.getLogger(__name__)
## Now using a format compatible with rich logging, it's prettier
log_format = "%(message)s"
date_format = "[%X]"
tab_handlers = [RichHandler(show_path=False)]
def pick_logger_level(debug,quiet):
    log_level = logging.INFO
    if debug:
        log_level = logging.DEBUG
    if quiet:
        log_level = logging.ERROR
    return log_level


################################################
################################################

################################################
## Organize the different commands in the help menu
################################################

click.rich_click.COMMAND_GROUPS = {
    "spacerextractor_mod": [
        {
            "name": "Match spacers to potential targets",
            "commands": ["create_target_db", "map_to_target"],
        },
    ],
}

click.rich_click.OPTION_GROUPS = {
    "spacerextractor_mod": [
        {
            "name": "Options",
            "options": ["--version", "--help"],
        },
    ],
    "spacerextractor_mod map_to_target": [
        {
            "name": "Main parameters",
            "options": ["--in_file", "--db_dir", "--out_dir", "--n_threads"],
        }
    ]
}

################################################
################################################

################################################
## These are options that will be used for every command, so we define them only once
################################################
def common_params(func):
    @click.option("-t", "--n_threads", required=False, default=2, help="number of threads to use", show_default=True)
    @click.option("-bmem", "--bbtools_memory", required=False, default="20g", help="memory allocated to bbtools", show_default=True)
    @click.option("--debug", is_flag=True, required=False, default=False, help="Run in a more verbose mode for debugging / troubleshooting purposes (warning: spacerextractor becomes quite chatty in this mode..)")
    @click.option("--quiet", is_flag=True, required=False, default=False, help="Run in a very quiet mode, will only show error/critical messages")
    @click.option("-fr", "--force_rerun", is_flag=True, required=False, default=False, help="If you want to force SpacerExtractor to recompute all the steps")
    @functools.wraps(func)
    def wrapper(*args, **kwargs):
        return func(*args, **kwargs)
    return wrapper

################################################
################################################


################################################
## Main help message
################################################
## Provide a graceful fallback for version metadata so the script can
## run directly from source (not installed as a package).
try:
    _pkg_version = "spacerextractor_mod"
except Exception:
    _pkg_version = "0+local"

@click.group("main", no_args_is_help=True)
@click.version_option(_pkg_version)
def cli():
    """:tractor::dna: [bold]Spacer Extractor[/] :tractor::dna: : [bold]extract spacers from metagenomic reads.[/]\n
    [green]The main commands are:\n
    [*] map_to_target to compare spacers to a database of potential targets[/]\n
    \n
    Use [bold]`spacerextractor_mod command` --help[/] for more details on specific commands (e.g. `spacerextractor_mod extract_spacers --help`)\n
    """

################################################
################################################

### map spacers to targets #######################
@cli.command("map_to_target")
@click.option("-i", "--in_file", type=click.Path(exists=True, file_okay=True, dir_okay=False, resolve_path=True, allow_dash=False), required=True, default=None, help="A fasta file of spacers")
@click.option("--db_dir","-d", type=click.Path(exists=False, file_okay=False, dir_okay=True, resolve_path=True, allow_dash=False), required=True, default=None, help="Path to the target database folder that was generated with create_target_db")
@click.option("--out_dir","-o", type=click.Path(exists=False, file_okay=False, dir_okay=True, resolve_path=True, allow_dash=False), required=True, default=None, help="Path to the output folder where temp files and result file will be written")
@common_params
def run(db_dir,in_file,out_dir,force_rerun,n_threads,bbtools_memory,debug,quiet):
    """ map spacers to a database of potential targets
    """
    args={"db_dir": db_dir, "in_sp": in_file, "out_dir": out_dir, "force": force_rerun, "version": "spacerextractor_mod","threads": n_threads}
    log_level = pick_logger_level(debug,quiet)
    logging.basicConfig(level=log_level, format=log_format, datefmt=date_format, handlers=tab_handlers)
    main(args)
################################################
################################################




import sys
import os
# import numpy as np
# np.set_printoptions(linewidth=np.inf)
# import pandas as pd
# pd.set_option('display.max_columns', None)
import glob
import csv
import shutil
import pyfaidx
import re
import itertools
import gzip
import json
import subprocess as sp
import multiprocessing as mp
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord
import logging
logger = logging.getLogger(__name__)
import os

def pathlite(path): ## Quick function to get just the file name and the parent directory, but not the entire path
	return "/.../" + os.path.join(os.path.basename(os.path.dirname(path)),os.path.basename(path))


def get_genus(vec):
	if vec != vec:
		return vec
	else:
		tab = vec.split(";")
		### Below is to remove any case where genus is unknown, but actually what we want is remove cases where we don't have any taxon info, so we'll do that differently
		# if tab[5] == "g__unclassified":
		# 	return np.NaN
		# else:
		# 	return ";".join(tab[0:6])
		### Instead, we return everything (up to genus) if we have any information, even 
		if len(tab)<6:
			return np.NaN
		else:
			return ";".join(tab[0:6])


def main(args):
    # set_default(args)
    for i in args:
        logger.debug(f"{i} -> {args[i]}")
    if not os.path.isfile(args["in_sp"]):
        logger.critical(f"Pblm, we could not find input file {pathlite(args['in_sp'])}")
        sys.exit(1)
    if not os.path.isdir(args["db_dir"]):
        logger.critical(f"We could not find the target dir db {pathlite(args['db_dir'])}")
        sys.exit(1)
    args['db_name'] = os.path.basename(args['db_dir'])
    args['spacer_name'] = os.path.splitext(os.path.basename(args['in_sp']))[0]
    logger.debug(f"db name -> {args['db_name']}")
    logger.debug(f"spacer name -> {args['spacer_name']}")
    args['sam_all'] = os.path.join(args['out_dir'],f"{args['spacer_name']}_vs_{args['db_name']}_all.sam")
    if not os.path.isdir(args["out_dir"]):
        logger.info(f"Mapping spacers to targets into {pathlite(args['out_dir'])}")
        os.mkdir(args["out_dir"])
        args["tmp_dir"] = os.path.join(args["out_dir"],"tmp_mapping")
        os.mkdir(args["tmp_dir"])
        get_mapping(args)
    else:
        logger.debug(f"dir {args['out_dir']} exists, now testing if the sam file {args['sam_all']} exists as well")
        if os.path.exists(args['sam_all']) and not args["force"]:
            logger.info(f"We will re-use {args['sam_all']} and go straight to post-processing")
        else:
            logger.info(f"Mapping spacers to targets into {pathlite(args['out_dir'])}")
            args["tmp_dir"] = os.path.join(args["out_dir"],"tmp_mapping")
            if not os.path.isdir(args["tmp_dir"]):
                os.mkdir(args["tmp_dir"])
            get_mapping(args)
    ## If we came here, we should have a clean sam file, which we can post-process
    args['tsv_all'] = os.path.join(args['out_dir'],f"{args['spacer_name']}_vs_{args['db_name']}_all_hits.tsv")
    post_process(args)

def get_mapping(args):
    logger.info("Mapping spacers to potential target")
    info_file = os.path.join(args['db_dir'],"db_info.json")
    ## Read json to get all the names and paths
    info_db = []
    with open(info_file, 'r') as j:
        info_db = json.loads(j.read())[0] ## First record, always
    logger.debug(f"Max batch number: {info_db['max_batch']}")
    ##
    list_done = []
    logger.info("Computing the mapping")
    log_bowtie1 = os.path.join(args['out_dir'],"bowtie1_map.log")
    for batch_n in range(info_db['max_batch']+1):
        logger.debug(f"Work on the batch {batch_n}")
        batch_name = f"batch_{batch_n:05d}"
        db_path = os.path.join(args['db_dir'],batch_name)
        tmp_out = os.path.join(args['tmp_dir'],batch_name+".sam")
        logger.info(f"... mapping batch {batch_name}")
        cmd = f"bowtie -x {db_path} -f {args['in_sp']} -a -v 3 --threads {args['threads']} -t --sam 2>> {log_bowtie1} | samtools view -F 4 > {tmp_out}"
        logger.debug(cmd)
        p = sp.run(cmd, shell=True)
        list_done.append(tmp_out)
    logger.debug(f"Concatenating everything into {args['sam_all']}")
    with open(args['sam_all'], 'wb') as outfile:
        for filename in list_done:
            with open(filename, 'rb') as infile:
                shutil.copyfileobj(infile, outfile)
    logger.info(f"We finished to generate all the mappings into {args['sam_all']}")

def post_process(args):
    logger.info("## Post-processing the mapping file to get a clean output table of all hits")
    ##
    dust_file = os.path.join(args["db_dir"],"targets.fna.dustmasker")
    logger.info(f"Loading dustmasker info from {dust_file} ..")
    info_dust = {}
    c_id = ""
    n_block = 0
    with open(dust_file, 'r') as fts:
        for line in fts:
            if line.startswith('>'):
                c_id = line.strip()[1:]
                n_block = 0
            else:
                t = line.strip().replace(' ', '').split("-")
                info_dust[c_id] = {}
                info_dust[c_id][n_block] = {"start": int(t[0]), "end": int(t[1])}
                n_block += 1
    ##
    logger.info(f"Loading hit info from {args['sam_all']}")  # Print message to indicate the table files being processed
    store = {}
    with open(args['sam_all'], 'r') as table:
        for line in table:
            cols = line.strip().split('\t')  # Split the line into columns by tab
            # Extract relevant information from the table
            spacer = cols[0]
            flag = int(cols[1])
            target = cols[2]
            start = int(cols[3])
            strand = '+' if flag == 0 else '-' if flag == 16 else None
            if strand is None:
                raise ValueError("Unexpected flag")
            cigar = cols[5]
            seq = cols[9]
            md_string = "NA"
            n_mis = "NA"
            for i in range(11,len(cols),1):
                if cols[i].startswith("MD:Z:"):
                    md_string = cols[i].split(":")[2]
                if cols[i].startswith("NM:i:"):
                    n_mis = int(cols[i].split(":")[2])
            ## Actually can't guarantee tag columns will always be exactly in the same place apparently, so better to do a quick loop as above
            # md_string = cols[13] if len(cols) > 12 else 'NA'
            # n_mis = int(re.split(r'\D+', cols[13])[1])
            # Store the extracted information in a dictionary
            store.setdefault(target, {}).setdefault(spacer, {}).setdefault(start, {})[strand] = {
                'seq': seq, 'CIGAR': cigar, 'n_mis': n_mis, 'md_string': md_string
            }
    ##
    # target_fa = os.path.join(args["db_dir"],"targets.fna")
    # logger.info(f"Reading fasta file {target_fa} ..")  # Print message to indicate reading the FASTA file
    # fasta = pyfaidx.Fasta(target_fa, read_ahead=1000000,  strict_bounds=False)
    ##
    logger.info("Writing output TSV file...")  # Print message to indicate writing the output file
    with open(args['tsv_all'], 'w') as out:
        writer = csv.writer(out, delimiter='\t')
        # writer.writerow(['Spacer id','Target id','Start','End','Strand','N mismatches','CIGAR','MD','spacer','protospacer','upstream','downstream','flags'])
        writer.writerow(['Spacer id','Target id','Start','End','Strand','N mismatches','CIGAR','MD','spacer','flags'])
        for target in store:
            for spacer in store[target]:
                for start in store[target][spacer]:
                    for strand in store[target][spacer][start]:
                        logger.debug(f"{target} / {spacer} / {start} / {strand} / {store[target][spacer][start][strand]}")
                        real_start = start - 1
                        if real_start < 0:
                            real_start = 0
                        spacer_seq = store[target][spacer][start][strand]['seq']
                        real_end = start + len(spacer_seq) -1
                        store[target][spacer][start][strand]['real_start'] = real_start
                        store[target][spacer][start][strand]['real_end'] = real_end
                        seq_id = target #+ ':' + str(real_start) + '-' + str(real_end)
                        # proto = fasta[seq_id] #[str(real_start),str(real_end)])
                        # upstream = 'NA'
                        # protospacer = 'NA'
                        # downstream = 'NA'
                        # protospacer = proto[real_start:real_end]
                        # logger.debug(protospacer)
                        if strand == '-':
                            ## If match on the minus strand, everything must be rev-comped, because by default bowtie rev-comp the input (spacer) but to get the correct upstream/downstream you need to rev-comp the protospacer
                            # protospacer=protospacer.reverse.complement
                            # downstream = proto[(real_start-10): real_start].reverse.complement
                            # upstream = proto[real_end : (real_end+10)].reverse.complement
                            spacer_seq = Seq(spacer_seq).reverse_complement()
                            ## Note -> You may also reverse-completement MD String if you want, but it does not matter that much, and maybe cleaner to keep the original MD from bowtie1
                        # if strand == '+':
                            # upstream = proto[(real_start-10): real_start]
                            # downstream = proto[real_end : (real_end+10)]
                        ## Padding upstream and downstream
                        # while (len(upstream)<10):
                        #     upstream = "N"+str(upstream)
                        # while (len(downstream)<10):
                        #     downstream = str(downstream)+"N"
                        ## Get pretty protospacer alignment
                        # protospacer = prettyfy(protospacer, spacer_seq, store[target][spacer][start][strand]['n_mis'])
                        ## Get flags
                        end = start + len(store[target][spacer][start][strand]['seq']) - 1
                        flags = get_flags(target,start,end,info_dust,store[target][spacer][start][strand]['n_mis'])
                        ## Write the output
                        # writer.writerow([spacer, target, start, end, strand, store[target][spacer][start][strand]['n_mis'], store[target][spacer][start][strand]['CIGAR'], store[target][spacer][start][strand]['md_string'], store[target][spacer][start][strand]['seq'], protospacer, upstream, downstream, flags])
                        writer.writerow([spacer, target, start, end, strand, store[target][spacer][start][strand]['n_mis'], store[target][spacer][start][strand]['CIGAR'], store[target][spacer][start][strand]['md_string'], store[target][spacer][start][strand]['seq'], flags])

# def prettyfy(proto, seq, exp_mis):
#     ret = ''
#     flag = 0
#     if len(proto) != len(seq):
#         flag = 4
#     ## In cases there are different cases, we move everything to upper
#     proto = str(proto).upper()
#     seq = str(seq).upper()
#     for i in range(len(proto)):
#         if proto[i] == seq[i]:
#             ret += '.'
#         elif str(proto[i]).upper() == str(seq[i]).upper(): ## Only try to do the conversion if we found a potential mismatch, avoid to have to convert every time when 99.9% of cases will not need a conversion.
#             ret += '.'
#         else:
#             ret += str(proto[i])
#             flag += 1
#     if flag > 3:
#         ## If the number of mismatches is greater than 3, log the sequences and exit with a critical error
#         logger.info(f"proto: {proto}")
#         logger.info(f"spacer: {seq}")
#         logger.critical("More than 3 mismatches between spacer and protospacer")
#         sys.exit(1)
#     elif flag != exp_mis:
#         ## If the number of mismatches does not match the expected number, log the discrepancy and exit with a critical error
#         logger.critical(f"Number of mismatches {flag} differs from expected number {exp_mis}")
#         sys.exit(1)
#     return ret

def get_flags(id,start,end,info_dust,n_mis):
    tmp = {}
    if id in info_dust:
        for block in info_dust[id]:
            if end < info_dust[id][block]["start"] or start > info_dust[id][block]["end"]:
                continue
            logger.debug("Found an overlap with dust region:")
            logger.debug(f"{id}\t{start}\t{end}\t{info_dust[id][block]['start']}\t{info_dust[id][block]['end']}")
            tmp["low_complexity"] = 1
    if n_mis > 1:
        tmp["mismatches"] = 1
    ### NOTE - THIS IS WHERE WE WILL ADD THE WARNING ABOUT POTENTIAL TARGET-ENCODED ARRAYS, ONE DAY
    combined_flags = ""
    if len(tmp) > 0:
        logger.debug(f"{tmp}")
        combined_flags = ";".join(sorted(tmp.keys()))
    return combined_flags



if __name__ == "__main__":
    # When executed directly (e.g. `./SE_map_get_hits.py ...`) invoke the
    # Click CLI entrypoint. The previous code attempted to call `main()` with
    # no arguments which fails when running as a script. Calling `cli()` lets
    # Click parse the command-line and run the appropriate subcommand.
    cli()
