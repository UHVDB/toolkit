#!/usr/bin/env python3

import re
import requests
from requests.adapters import HTTPAdapter, Retry

re_next_link = re.compile(r'<(.+)>; rel="next"')
retries = Retry(total=5, backoff_factor=0.25, status_forcelist=[500, 502, 503, 504])
session = requests.Session()
session.mount("https://", HTTPAdapter(max_retries=retries))

def get_next_link(headers):

    if "Link" in headers:
        match = re_next_link.match(headers["Link"])
        if match:
            return match.group(1)

def get_batch(batch_url):
    while batch_url:
        response = session.get(batch_url)
        response.raise_for_status()
        total = response.headers["x-total-results"]
        yield response, total
        batch_url = get_next_link(response.headers)

def main(fasta_url, output_fasta):
    retries = Retry(total=5, backoff_factor=0.25, status_forcelist=[500, 502, 503, 504])
    session = requests.Session()
    session.mount("https://", HTTPAdapter(max_retries=retries))

    # download fasta
    progress = 0
    with open('tmp.fasta', 'w') as f:
        for batch, total in get_batch(fasta_url):
            lines = batch.text.splitlines()
            if not progress:
                print(lines[0], file=f)
            for line in lines[1:]:
                print(line, file=f)
            progress += len(lines[1:])
            print(f'{progress} / {total}')

    # filter fasta to only include proteins with functional names
    # also format fasta for Bakta
    with open('tmp.fasta') as f_in:
        lines = f_in.readlines()
    with open(output_fasta, 'w') as f_out:
        for line in lines:
            if line.startswith('>'):
                accession = line[1:].split()[0]
                accession = accession.replace('UniRef50_', 'UniRef30_')
                # format header for Bakta
                rep = line.split('RepID=')[1].split()[0]
                name = line.split(' n=')[0].split(maxsplit=1)[1]
                if 'Uncharacterized protein n=' in line or 'Phage protein n=' in line or 'hypothetical protein n=' in line:
                    name = 'hypothetical protein'
                line = f">{accession} 30~~~80~~~80~~~{rep}~~~{name}~~~UniRef:{accession}"
                write_flag = True
                print(line.strip(), file=f_out)
            else:
                print(line.strip(), file=f_out)


if __name__ == "__main__":

    # download
    main(
        "https://rest.uniprot.org/uniref/search?format=fasta&query=%28%28taxonomy_id%3A10239%29+AND+%28identity%3A0.5%29+NOT+%28name%3A%28Fragment%29%29%29&size=500",
        "uniref50_virus.faa"
    )
