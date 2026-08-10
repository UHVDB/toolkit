# Phold with CUDA-enabled PyTorch (biocontainers phold is CPU-only by default).
FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends git wget ca-certificates && \
    conda install -y -c conda-forge -c bioconda phold=1.2.2 && \
    pip install --no-cache-dir tiktoken && \
    conda clean -afy && \
    rm -rf /var/lib/apt/lists/*

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
