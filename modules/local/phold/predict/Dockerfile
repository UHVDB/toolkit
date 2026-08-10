# Phold with CUDA-enabled PyTorch (biocontainers phold is CPU-only by default).
# Install via pip to avoid slow/fragile conda solves against the pytorch base image.
# Base >=2.5 required by current transformers dependency of phold.
FROM pytorch/pytorch:2.5.1-cuda12.1-cudnn9-runtime

RUN apt-get update && \
    apt-get install -y --no-install-recommends git wget ca-certificates && \
    pip install --no-cache-dir phold==1.2.2 tiktoken && \
    rm -rf /var/lib/apt/lists/*

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
