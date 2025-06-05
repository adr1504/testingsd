# Usamos una imagen base con CUDA 11.8
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV LD_PRELOAD=libtcmalloc_minimal.so.4
# API key actualizada de CivitAI
ENV CIVITAI_API_KEY=ce7555dd88241242076f59bee3af8ecc

# Instalar dependencias del sistema con Python 3.10
RUN apt-get update && \
    apt-get install -y \
    git \
    wget \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    libgl1 \
    libglib2.0-0 \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    aria2 \
    psmisc \
    && ln -s /usr/bin/python3.10 /usr/bin/python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crear y activar entorno virtual Python
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Instalar dependencias básicas de Python
RUN pip install --no-cache-dir --upgrade pip wheel setuptools

# Instalar PyTorch con CUDA 11.8
RUN pip install --no-cache-dir \
    torch==2.0.1+cu118 \
    torchvision==0.15.2+cu118 \
    torchaudio==2.0.2 \
    --index-url https://download.pytorch.org/whl/cu118

# Clonar ReForge
WORKDIR /app
RUN git clone https://github.com/Panchovix/stable-diffusion-webui-reForge --depth=1

# Configurar estructura de directorios para RunPod
RUN mkdir -p /workspace/{models,outputs} && \
    ln -s /workspace/models /app/stable-diffusion-webui-reForge/models && \
    ln -s /workspace/outputs /app/stable-diffusion-webui-reForge/outputs

# Instalar extensiones
WORKDIR /app/stable-diffusion-webui-reForge/extensions
RUN git clone https://github.com/BlafKing/sd-civitai-browser-plus.git --depth=1 && \
    git clone https://github.com/DominikDoom/a1111-sd-webui-tagcomplete.git --depth=1 && \
    git clone https://github.com/Bing-su/adetailer.git --depth=1 && \
    git clone https://github.com/hako-mikan/sd-webui-regional-prompter.git --depth=1 && \
    git clone https://github.com/NoCrypt/sd-fast-pnginfo.git --depth=1

# Configurar API key actualizada de CivitAI
RUN echo $CIVITAI_API_KEY > sd-civitai-browser-plus/api_key.txt

# Instalar dependencias de WebUI
WORKDIR /app/stable-diffusion-webui-reForge
RUN pip install --no-cache-dir -r requirements_versions.txt

# Crear script de inicio optimizado
RUN echo '#!/bin/bash\n' > /start.sh && \
    echo 'source /app/venv/bin/activate\n' >> /start.sh && \
    echo 'cd /app/stable-diffusion-webui-reForge\n' >> /start.sh && \
    echo 'echo $CIVITAI_API_KEY > extensions/sd-civitai-browser-plus/api_key.txt\n' >> /start.sh && \
    echo 'python launch.py \\\n' >> /start.sh && \
    echo '  --listen \\\n' >> /start.sh && \
    echo '  --enable-insecure-extension-access \\\n' >> /start.sh && \
    echo '  --skip-torch-cuda-test \\\n' >> /start.sh && \
    echo '  --no-download-sd-model \\\n' >> /start.sh && \
    echo '  --xformers \\\n' >> /start.sh && \
    echo '  --skip-prepare-environment\n' >> /start.sh && \
    chmod +x /start.sh

# Exponer puerto y configurar entrada
EXPOSE 7860
CMD ["/start.sh"]
