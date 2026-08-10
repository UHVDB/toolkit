/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// Remove empty fasta files from a channel
//
def rmEmptyFastAs(ch_fastas) {
    // if not stub run, remove empty fasta files
    if (!workflow.stubRun) {
        def ch_nonempty_fastas = ch_fastas
            .filter { _meta, fasta ->
                try {
                    file(fasta).countFasta( limit: 1 ) > 0
                } catch (java.util.zip.ZipException _e) {
                    log.debug "[rmEmptyFastAs]: ${fasta} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                    true
                } catch (_EOFException) {
                    log.debug "[rmEmptyFastAs]: ${fasta} has an EOFException, this is likely an empty gzipped file."
                }
            }
        return ch_nonempty_fastas
    }
    // if stub run, return the input channel
    else {
        return ch_fastas
    }
}

//
// Remove empty tsv files from a channel
//
def rmEmptyTsvs(ch_tsvs) {
    // if not stub run, remove empty tsv files
    if (!workflow.stubRun) {
        def ch_nonempty_tsvs = ch_tsvs
            .filter { _meta, tsv ->
                try {
                    file(tsv).countLines( limit: 2 ) > 1
                } catch (java.util.zip.ZipException _e) {
                    log.debug "[rmEmptyTsvss]: ${tsv} is not in GZIP format, this is likely because it was cleaned with --remove_intermediate_files"
                    true
                } catch (_EOFException) {
                    log.debug "[rmEmptyTsvss]: ${tsv} has an EOFException, this is likely an empty gzipped file."
                }
            }
        return ch_nonempty_tsvs
    }
    // if stub run, return the input channel
    else {
        return ch_tsvs
    }
}

//
// Count the number of sequences in a channel of fasta files
//
def countFastAs(ch_fastas) {
    // if not stub run, count the number of sequences in the fasta files
    if (!workflow.stubRun) {
        def ch_fastas_counts = ch_fastas
            .map { _meta, fasta ->
                file(fasta).countFasta( limit: params.min_checkv_update )
            }
            .sum()
        return ch_fastas_counts
    }
    // if stub run, return the minimum checkv update
    else {
        return channel.value(params.min_checkv_update)
    }
}

//
// Extract the number before the file extension
//
def extractDigitBeforeExtension(String path) {
    // Regex pattern to match the digit before the file extension
    def pattern = /(\d+)\.(?:fasta|fna|faa)(?:\.gz)?$/

    // Extract the digit
    def matcher = path =~ pattern
    if (matcher.find()) {
        return matcher[0][1]
    } else {
        return null
    }
}

//
// Add the split number to a channel's meta
//
def add_split(Map meta, String read){
    def new_meta = [:]

    meta.each{ k,v ->
        new_meta[k] = v}

    new_meta.id = new_meta.id + "_split" + extractDigitBeforeExtension(read)

    return new_meta
}