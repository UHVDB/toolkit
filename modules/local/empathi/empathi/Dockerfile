# Empathi with CUDA PyTorch (same stack as embeddings for ABI consistency).
FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime

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
