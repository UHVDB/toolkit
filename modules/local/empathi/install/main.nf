process EMPATHI_INSTALL {
    tag "Empathi v1.0.6"
    label 'process_single'
    storeDir "${params.dbdir}/empathi/1.0.6"

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'docker://docker.io/carsonjm/empathi:1.0.6-cuda12.1' :
        'docker.io/carsonjm/empathi:1.0.6-cuda12.1' }"

    output:
    path("empathi/models/"), emit: models
    path("huggingface/")  , emit: hf_cache

    script:
    """
    ### Install git lfs
    git lfs install

    ### Clone empathi models
    git clone https://huggingface.co/AlexandreBoulay/empathi

    ### Prefetch ProtT5 into a shared Hugging Face cache for offline embedding jobs
    export HF_HOME="\$PWD/huggingface"
    export HUGGINGFACE_HUB_CACHE="\${HF_HOME}/hub"
    export TRANSFORMERS_CACHE="\${HF_HOME}/transformers"
    export TORCH_HOME="\${HF_HOME}/torch"
    mkdir -p "\$HF_HOME" "\$HUGGINGFACE_HUB_CACHE" "\$TRANSFORMERS_CACHE" "\$TORCH_HOME"

    python -c 'from transformers import T5EncoderModel, T5Tokenizer; import torch; name="Rostlab/prot_t5_xl_half_uniref50-enc"; T5Tokenizer.from_pretrained(name); T5EncoderModel.from_pretrained(name, torch_dtype=torch.float32)'
    """

    stub:
    """
    mkdir -p empathi/models huggingface
    touch empathi/models/.stub
    touch huggingface/.stub
    """
}
