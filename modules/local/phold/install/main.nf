process PHOLD_INSTALL {
    tag "Phold v1.2.2"
    label 'process_gpu'
    storeDir "${params.dbdir}/phold/1.2.2"

    // Docker Hub image (docker.io/ required — pipeline default registry is quay.io)
    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/phold:1.2.2-cuda12.1' :
        'docker.io/carsonjm/phold:1.2.2-cuda12.1' }"

    output:
    path("phold_db/"), emit: db

    script:
    """
    ### Workaround: image torch==2.5.1; newer transformers refuse torch.load (CVE-2025-32434).
    pip install --no-cache-dir --target ./tf_pin 'transformers==4.48.3'
    export PYTHONPATH="\$PWD/tf_pin\${PYTHONPATH:+:\$PYTHONPATH}"

    ### Image has phold but no foldseek binary; phold install needs it for makepaddedseqdb.
    wget -q https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz
    tar -xzf foldseek-linux-gpu.tar.gz
    export PATH="\$PWD/foldseek/bin:\$PATH"
    command -v foldseek

    # download phold database with FoldSeek-GPU layout
    phold install \\
        -d phold_db \\
        -t ${task.cpus} \\
        --foldseek_gpu

    ### Foldseek leaves absolute scrubbed-work symlinks for *_gpu*; rewrite to relative
    ### siblings so storeDir/publishDir copy does not abort the Nextflow session.
    (
      cd phold_db
      [[ -e all_phold_structures ]] && ln -sfn all_phold_structures all_phold_structures_gpu
      [[ -e all_phold_structures_ca ]] && ln -sfn all_phold_structures_ca all_phold_structures_gpu_ca
      [[ -e all_phold_structures_h ]] && ln -sfn all_phold_structures_h all_phold_structures_gpu_h
      [[ -e all_phold_structures.source ]] && ln -sfn all_phold_structures.source all_phold_structures_gpu.source
    )
    """

    stub:
    """
    mkdir -p phold_db
    touch phold_db/.stub
    """
}
