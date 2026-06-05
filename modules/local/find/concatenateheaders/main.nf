process FIND_CONCATENATEHEADERS {
    tag "${meta.id}"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7f/7fd226561e12b32bcacdf4f5ff74577e76233adf52ae5cbc499a2cdfe0e27d82/data'
        : 'community.wave.seqera.io/library/findutils_pigz:c4dd5edc44402661'}"

    input:
    tuple val(meta), path(files_in, stageAs: 'to_concatenate/*', arity: '1..*')
    val header_row_count

    output:
    tuple val(meta), path("${prefix}"), emit: file_out
    tuple val("${task.process}"), val("find"), eval("find --version | sed '1!d; s/.* //'"), topic: versions, emit: versions_find
    tuple val("${task.process}"), val("pigz"), eval("pigz --version 2>&1 | sed 's/pigz //g'"), topic: versions, emit: versions_pigz
    tuple val("${task.process}"), val("coreutils"), eval("cat --version | sed '1!d; s/.* //'"), topic: versions, emit: versions_coreutils

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ""

    // | input     | output     | command1 | command2 |
    // |-----------|------------|----------|----------|
    // | gzipped   | gzipped    | cat      |          |
    // | ungzipped | ungzipped  | cat      |          |
    // | gzipped   | ungzipped  | pigz     |          |
    // | ungzipped | gzipped    | cat      | pigz     |

    // Use input file ending as default
    // get file extensions, if extension is .gz then get the second to last extension as well
    file_extensions = files_in.collect { in_file -> in_file.name - in_file.getBaseName(in_file.name.endsWith('.gz') ? 2 : 1) }

    // Use input file ending as default for output file
    prefix = task.ext.prefix ?: "${meta.id}${file_extensions[0]}"

    if (files_in.any{ file -> file.toString().endsWith('.gz')} && !files_in.every{ file -> file.toString().endsWith('.gz') }) {
        error("All files provided to this module must either be gzipped (and have the .gz extension) or unzipped (and not have the .gz extension). A mix of both is not allowed.")
    }

    in_zip = files_in[0].toString().endsWith('.gz')
    out_fname = prefix.replace('.gz', '')

    cmd0 = in_zip ? "pigz -cd -p ${task.cpus}" : "cat"
    cmd1 = in_zip ? "pigz -cd -p ${task.cpus}" : "cat"
    cmd2 =  "pigz -p ${task.cpus} ${args} ${out_fname}"

    """
    ### Output header from first file
    first_file=\$(find to_concatenate/ -mindepth 1 | sort | head -n 1)
    ${cmd0} "\${first_file}" | head -n ${header_row_count} > ${out_fname} || [ \${PIPESTATUS[0]} -eq 0 -o \${PIPESTATUS[0]} -eq 141 ]

    while IFS= read -r -d \$'\\0' file; do
            ${cmd1} \$file | tail -n +${header_row_count + 1} \\
                >> ${out_fname}
        done < <( find to_concatenate/ -mindepth 1 -print0 | sort -z )

    ${cmd2}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"

    if (files_in.any{ file -> file.toString().endsWith('.gz')} && !files_in.every{ file -> file.toString().endsWith('.gz') }) {
        error("All files provided to this module must either be gzipped (and have the .gz extension) or unzipped (and not have the .gz extension). A mix of both is not allowed.")
    }

    """
    touch ${prefix}
    """
}
