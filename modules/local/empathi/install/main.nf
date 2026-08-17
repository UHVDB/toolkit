process EMPATHI_INSTALL {
    tag "Empathi v1.0.6"
    label 'process_single'
    storeDir "${params.dbdir}/empathi/1.0.6"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/8b/8b8a045eec34dae0f3027ab806e8f218a77c5755355480688e500ef644dd5473/data' :
        'community.wave.seqera.io/library/git_git-lfs:latest' }"

    output:
    path("empathi/models/"), emit: models

    script:
    """
    ### Bootstrap git-lfs if the container lacks it (wget preferred; curl fallback)
    if ! git lfs version >/dev/null 2>&1; then
        if command -v wget >/dev/null 2>&1; then
            wget -q -O git-lfs.tgz \\
                https://github.com/git-lfs/git-lfs/releases/download/v3.5.1/git-lfs-linux-amd64-v3.5.1.tar.gz
        elif command -v curl >/dev/null 2>&1; then
            curl -fsSL -o git-lfs.tgz \\
                https://github.com/git-lfs/git-lfs/releases/download/v3.5.1/git-lfs-linux-amd64-v3.5.1.tar.gz
        else
            echo "ERROR: git-lfs missing and neither wget nor curl is available" >&2
            exit 127
        fi
        tar -xzf git-lfs.tgz
        export PATH="\$PWD/git-lfs-3.5.1:\$PATH"
    fi

    ### Install git lfs
    git lfs install

    ### Clone empathi models
    git clone https://huggingface.co/AlexandreBoulay/empathi
    """

    stub:
    """
    mkdir -p empathi/models
    touch empathi/models/.stub
    """
}
