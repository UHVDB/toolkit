# FoldSeek with official CUDA/GPU static binary (ProstT5 --gpu support).
# Biocontainers foldseek builds are CPU-only and will fail with --gpu 1.
FROM nvidia/cuda:12.1.1-runtime-ubuntu22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates tar gzip && \
    wget -q https://mmseqs.com/foldseek/foldseek-linux-gpu.tar.gz && \
    tar -xzf foldseek-linux-gpu.tar.gz && \
    mv foldseek/bin/foldseek /usr/local/bin/foldseek && \
    chmod +x /usr/local/bin/foldseek && \
    rm -rf foldseek foldseek-linux-gpu.tar.gz /var/lib/apt/lists/*

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
