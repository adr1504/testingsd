FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu22.04

# Configuración general
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Instalar dependencias necesarias
RUN apt-get update && \
    apt-get install -y git wget curl libgl1 libglib2.0-0 libgoogle-perftools-dev python3 python3-pip && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip install --upgrade pip setuptools

# Crear carpeta de trabajo
WORKDIR /workspace

# Clonar Stable Diffusion WebUI ReForge
RUN git clone https://github.com/Panchovix/stable-diffusion-webui-reForge.git stable-diffusion-webui
WORKDIR /workspace/stable-diffusion-webui

# Instalar extensiones
RUN git clone https://github.com/BlafKing/sd-civitai-browser-plus.git extensions/sd-civitai-browser-plus && \
    git clone https://github.com/DominikDoom/a1111-sd-webui-tagcomplete.git extensions/a1111-sd-webui-tagcomplete && \
    git clone https://github.com/Bing-su/adetailer.git extensions/adetailer && \
    git clone https://github.com/hako-mikan/sd-webui-regional-prompter.git extensions/sd-webui-regional-prompter && \
    git clone https://github.com/NoCrypt/sd-fast-pnginfo.git extensions/sd-fast-pnginfo

# Añadir API key a la extensión Civitai Browser Plus
RUN echo '{ "api_key": "ce7555dd88241242076f59bee3af8ecc" }' > extensions/sd-civitai-browser-plus/config.json

# Instalar requirements (solo los necesarios para evitar conflictos)
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121 && \
    pip install -r requirements.txt && \
    pip install xformers

# Modificar script de lanzamiento con opciones personalizadas
RUN echo '#!/bin/bash\n'\
'python launch.py \\\n'\
'--enable-insecure-extension-access \\\n'\
'--xformers \\\n'\
'--share \\\n'\
'--update-all-extensions \\\n'\
'--cuda-stream "$@"' > webui-user.sh && chmod +x webui-user.sh

# Exponer el puerto
EXPOSE 7860

# Comando por defecto
CMD ["./webui-user.sh"]