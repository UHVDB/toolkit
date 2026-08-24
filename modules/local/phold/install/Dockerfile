# Phold with CUDA-enabled PyTorch (biocontainers phold is CPU-only by default).
# Install via pip to avoid slow/fragile conda solves against the pytorch base image.
# Base >=2.5 required by current transformers dependency of phold.
# Foldseek GPU v10 is required for `phold install --foldseek_gpu` and `proteins-compare --foldseek_gpu`.
# Pin transformers==4.48.3 with torch 2.5.1 (newer transformers refuse torch.load; CVE-2025-32434).
# Keep in sync with modules/local/phold/{predict,compare,install}/Dockerfile
FROM pytorch/pytorch:2.5.1-cuda12.1-cudnn9-runtime

ARG FOLDSEEK_VERSION=10-941cd33
ARG FOLDSEEK_SHA256=af7a688ffd8625b356c380380fb5650ec811262a2d18bdb0faeda95cc4894a55

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    wget -q -O /tmp/foldseek-linux-gpu.tar.gz \
        "https://github.com/steineggerlab/foldseek/releases/download/${FOLDSEEK_VERSION}/foldseek-linux-gpu.tar.gz" && \
    echo "${FOLDSEEK_SHA256}  /tmp/foldseek-linux-gpu.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/foldseek-linux-gpu.tar.gz -C /tmp && \
    mv /tmp/foldseek/bin/foldseek /usr/local/bin/foldseek && \
    chmod +x /usr/local/bin/foldseek && \
    rm -rf /tmp/foldseek /tmp/foldseek-linux-gpu.tar.gz /var/lib/apt/lists/*

RUN pip install --no-cache-dir phold==1.2.2 tiktoken transformers==4.48.3

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
