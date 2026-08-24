include { UHBDB_DOWNLOAD      } from '../../../modules/local/uhbdb/download/main'
include { PHIST_BUILD         } from '../../../modules/local/phist/build/main'
include { PHIST_LISTSETS      } from '../../../modules/local/phist/listsets/main'
include { PHIST_UHBDB         } from '../../../modules/local/phist/uhbdb/main'
include { PHIST_AGC           } from '../../../modules/local/phist/agc/main'
include { UHVDB_PHISTHOST     } from '../../../modules/local/uhvdb/phisthost/main'

workflow PHISTHOST {

    take:
    fna_gz

    main:

    //
    // MODULE: Download UHBDB database
    //
    UHBDB_DOWNLOAD()

    //
    // MODULE: Create a PHIST kmer-db from all virus sequence chunks
    //
    PHIST_BUILD(
        fna_gz
            .map { _meta, fna -> fna }
            .collect()
            .map { fnas -> [ [ id: 'new_genomovars' ], fnas ] }
    )

    ch_virus_kdb = PHIST_BUILD.out.kdb.first()

    //
    // Branch UHBDB AGCs: large archives are sample-chunked for in-job extraction
    //
    ch_agcs = UHBDB_DOWNLOAD.out.uhbdb_dir
        .flatMap { dir ->
            files("${dir}/**/*.agc", checkIfExists: true).collect { agc ->
                [ [ id: agc.baseName ], agc ]
            }
        }

    ch_agcs_branched = ch_agcs.branch { meta, agc ->
        large: agc.size() >= params.phist_agc_split_min_bytes
        small: true
    }

    //
    // MODULE: List AGC samples and split into chunks (no persistent FASTA extract)
    // Skipped for the test UHVDB; only small AGCs are processed
    //
    ch_large_agcs = ch_agcs_branched.large
        .filter { _meta, _agc -> params.uhvdb_version != 'test' }

    PHIST_LISTSETS(
        ch_large_agcs,
        params.phist_host_chunk_size
    )

    ch_agc_sample_chunks = PHIST_LISTSETS.out.sample_chunks
        .flatMap { meta, agc, chunks ->
            def chunk_list = chunks instanceof List ? chunks : [chunks]
            chunk_list.collect { chunk ->
                [ [ id: "${meta.id}_${chunk.simpleName}" ], agc, chunk ]
            }
        }

    //
    // MODULE: Extract sample chunk from AGC in-job and run PHIST
    //
    PHIST_UHBDB(
        ch_agc_sample_chunks,
        ch_virus_kdb
    )

    //
    // MODULE: Run PHIST on small AGCs in-job (no sample chunking)
    //
    ch_small_agc_chunks = ch_agcs_branched.small
        .map { _meta, agc -> agc }
        .collate(10)
        .toList()
        .flatMap { chunks ->
            chunks.withIndex().collect { agc_list, index ->
                [ [ id: "small_chunk_${index}" ], agc_list ]
            }
        }

    PHIST_AGC(
        ch_small_agc_chunks,
        ch_virus_kdb
    )

    //
    // MODULE: Combine results and extract PHIST host taxonomy
    //
    UHVDB_PHISTHOST(
        PHIST_UHBDB.out.csv_gz
            .mix(PHIST_AGC.out.csv_gz)
            .map { _meta, csv_gz -> csv_gz }
            .collect()
            .map { csv_gzs -> [ [ id: 'new_genomovars' ], csv_gzs ] },
        UHBDB_DOWNLOAD.out.uhbdb_dir
    )

    emit:
    phisthost_tsv_gz = UHVDB_PHISTHOST.out.phisthost_tsv_gz
    phist_tsv_gz     = UHVDB_PHISTHOST.out.phist_tsv_gz
}
