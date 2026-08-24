# Empathi with CUDA PyTorch for ProtT5 embeddings.
# Base must be Python >=3.11.5 (empathi requirement); 2.3.x images ship 3.10.
# empathi==1.0.6 pins torch==2.3.0, which will replace the base torch.
FROM pytorch/pytorch:2.4.1-cuda12.1-cudnn9-runtime

# git-lfs is required to clone Hugging Face Empathi models in EMPATHI_INSTALL
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        git-lfs \
    && git lfs install --system \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
        empathi==1.0.6 \
        transformers==4.43.1 \
        sentencepiece==0.2.0 \
        joblib==1.2.0 \
        pandas==2.2.1 \
        scipy==1.13.1 \
        scikit-learn==1.5.0

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
