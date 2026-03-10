process EMPATHI_INSTALL {
    label "process_gpu"
    container null
    conda "${moduleDir}/environment.yml"
    storeDir "${params.db_dir}/empathi/1.0.6"
    tag "Empathi v1.0.6"
    
    output:
    path("empathi/models/") , emit: models
    path(".command.log")    , emit: log
    path(".command.sh")     , emit: script

    script:
    """
    ### Install git lfs
    git lfs install

    ### Clone empathi
    git clone https://huggingface.co/AlexandreBoulay/empathi
    export PATH="empathi/models:\$PATH"

    ### Install empathi
    export PIP_CACHE_DIR=${params.db_dir}/.pip-cache
    pip install empathi==1.0.6
    """
}
