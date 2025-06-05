# Dockerfile for Stable Diffusion WebUI with Extensions - ReForge Version
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/root/miniconda3/bin:$PATH"

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    aria2 \
    curl \
    ca-certificates \
    python3 \
    python3-pip \
    libgl1 \
    libglib2.0-0 \
    git-lfs \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda with hash check
RUN aria2c -x 16 -s 16 -o miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    && echo "5c49145e469f31d96f65c3cd5c8e3d3d2d0a6cb3b2378e26792e9f433d5cbe52  miniconda.sh" | sha256sum -c - \
    && bash miniconda.sh -b -p /root/miniconda3 \
    && rm miniconda.sh

# Clone the ReForge WebUI
WORKDIR /stable-diffusion-webui
RUN git clone https://github.com/Panchovix/stable-diffusion-webui-reForge .

# Add webui-user.sh with startup arguments
RUN echo "#!/bin/bash\n\
export COMMANDLINE_ARGS=\"--enable-insecure-extension-access --xformers --share --update-all-extensions --cuda-stream\"\n\
exec bash webui.sh \"$@\"" > webui-user.sh && \
    chmod +x webui-user.sh

# Install Extensions
RUN git clone https://github.com/BlafKing/sd-civitai-browser-plus extensions/sd-civitai-browser-plus && \
    echo "API_KEY=ce7555dd88241242076f59bee3af8ecc" > extensions/sd-civitai-browser-plus/config.env && \
    git clone https://github.com/DominikDoom/a1111-sd-webui-tagcomplete extensions/a1111-sd-webui-tagcomplete && \
    git clone https://github.com/Bing-su/adetailer extensions/adetailer && \
    git clone https://github.com/hako-mikan/sd-webui-regional-prompter extensions/sd-webui-regional-prompter && \
    git clone https://github.com/NoCrypt/sd-fast-pnginfo extensions/sd-fast-pnginfo

# Download the checkpoint model with hash check
RUN mkdir -p /stable-diffusion-webui/models/Stable-diffusion && \
    aria2c -x 16 -s 16 -o /stable-diffusion-webui/models/Stable-diffusion/model.safetensors \
    https://civitai.com/api/download/models/1761560 && \
    echo "d46b17f17674fa3f1e5ea4d8e5e9dd01bbdb7c4d63ec32f7a0d69ea162172c15  /stable-diffusion-webui/models/Stable-diffusion/model.safetensors" | sha256sum -c -

# Expose default port
EXPOSE 7860

# Entry point
CMD ["./webui-user.sh"]
