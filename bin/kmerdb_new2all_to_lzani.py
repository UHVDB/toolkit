#!/usr/bin/env python

import argparse

def parse_args(args=None):
    description = "Convert kmer-db's new2all dist output to a format accetpable by LZ-ANI."
    epilog = "Example usage: python kmerdb_new2all_to_lzani.py --help"

    parser = argparse.ArgumentParser(description=description, epilog=epilog)
    parser.add_argument(
        "-i",
        "--input",
        help="Path to distance CSV created by kmer-db distance following kmer-db new2all.",
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output CSV reformatted to match LZ-ANI's filter file structure.",
    )
    parser.add_argument('--version', action='version', version='1.0.0')
    return parser.parse_args(args)


def modify_ani_file(input_file, output_file):
    with open(input_file, 'r') as infile:
        lines = infile.readlines()

    # Extract the header and references
    header = lines[0].strip().split(',')[0:-1]
    references = header[1:]  # Skip the first column (query names)

    queries = []
    for line in lines[1:]:
        query_id = line.strip().split(',')[0]
        queries.append(query_id)

    # Append query IDs to the header
    header.extend(queries)

    # Create new rows for references
    reference_rows = []
    for ref in references:
        reference_rows.append(f"{ref},\n")  # Add a comma to match the format

    # Combine the modified header, reference rows, and original data
    modified_lines = [','.join(header) + '\n'] + reference_rows + lines[1:]

    # Write the modified content to the output file
    with open(output_file, 'w') as outfile:
        outfile.writelines(modified_lines)


def main(args=None):
    args = parse_args(args)

    # Modify the file
    modify_ani_file(args.input, args.output)

if __name__ == "__main__":
    main()
