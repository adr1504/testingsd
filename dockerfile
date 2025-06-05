# Usar imagen base más estable con CUDA 11.8
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

# Configurar variables de entorno críticas
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Etc/UTC \
    LD_PRELOAD=libtcmalloc_minimal.so.4 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on

# Configurar zona horaria y repositorios
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get update -yq --fix-missing && \
    apt-get install -yq --no-install-recommends software-properties-common ca-certificates && \
    add-apt-repository -y universe && \
    add-apt-repository -y multiverse && \
    apt-get update -yq --fix-missing

# Instalar dependencias del sistema con manejo robusto de errores
RUN apt-get install -yq --no-install-recommends \
    git \
    wget \
    python3.10 \
    python3.10-venv \
    python3.10-dev \
    libgl1 \
    libglib2.0-0 \
    aria2 \
    psmisc \
    libgoogle-perftools4 \
    libtcmalloc-minimal4 \
    && ln -s /usr/bin/python3.10 /usr/bin/python3 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Crear y activar entorno virtual Python
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Instalar dependencias básicas de Python
RUN pip install --upgrade pip wheel setuptools

# Instalar PyTorch con CUDA 11.8 (versiones compatibles)
RUN pip install \
    torch==2.0.1+cu118 \
    torchvision==0.15.2+cu118 \
    torchaudio==2.0.2 \
    --index-url https://download.pytorch.org/whl/cu118

# Clonar ReForge con manejo de errores
WORKDIR /app
RUN git clone https://github.com/Panchovix/stable-diffusion-webui-reForge --depth=1 || \
    { echo "Falló clonación principal. Reintentando..."; git clone https://github.com/Panchovix/stable-diffusion-webui-reForge --depth=1; }

# Configurar estructura de directorios para RunPod
RUN mkdir -p /workspace/{models,outputs,extensions} && \
    ln -s /workspace/models /app/stable-diffusion-webui-reForge/models && \
    ln -s /workspace/outputs /app/stable-diffusion-webui-reForge/outputs && \
    ln -s /workspace/extensions /app/stable-diffusion-webui-reForge/extensions

# Instalar extensiones con reintentos
WORKDIR /app/stable-diffusion-webui-reForge/extensions
RUN for repo in \
    https://github.com/BlafKing/sd-civitai-browser-plus.git \
    https://github.com/DominikDoom/a1111-sd-webui-tagcomplete.git \
    https://github.com/Bing-su/adetailer.git \
    https://github.com/hako-mikan/sd-webui-regional-prompter.git \
    https://github.com/NoCrypt/sd-fast-pnginfo.git; \
    do \
        echo "Clonando $repo"; \
        git clone $repo --depth=1 || git clone $repo --depth=1; \
        echo "Extensión clonada"; \
    done

# Instalar dependencias de WebUI con optimización
WORKDIR /app/stable-diffusion-webui-reForge
RUN pip install --no-cache-dir -r requirements_versions.txt

# Crear script de inicio mejorado
RUN printf '#!/bin/bash\n\n\
source /app/venv/bin/activate\n\n\
cd /app/stable-diffusion-webui-reForge\n\n\
# Configurar API key solo si se proporciona\n\
if [ -n "$CIVITAI_API_KEY" ]; then\n\
    echo "Configurando API key de CivitAI..."\n\
    echo "$CIVITAI_API_KEY" > extensions/sd-civitai-browser-plus/api_key.txt\n\
fi\n\n\
# Actualizar extensiones al iniciar\n\
echo "Actualizando extensiones..."\n\
for dir in extensions/*/; do\n\
    if [ -d "$dir/.git" ]; then\n\
        echo "Actualizando $dir"\n\
        (cd "$dir" && git pull origin main || git pull origin master)\n\
    fi\n\
done\n\n\
# Optimizar para GPUs NVIDIA\n\
export NVIDIA_DRIVER_CAPABILITIES=compute,utility\n\
export NVIDIA_VISIBLE_DEVICES=all\n\n\
# Iniciar WebUI con parámetros optimizados\n\
python -u launch.py \\\n\
    --listen \\\n\
    --port 7860 \\\n\
    --enable-insecure-extension-access \\\n\
    --skip-torch-cuda-test \\\n\
    --no-download-sd-model \\\n\
    --xformers \\\n\
    --skip-prepare-environment \\\n\
    --skip-install \\\n\
    --disable-safe-unpickle \\\n\
    --disable-console-progressbars\n' > /start.sh && \
    chmod +x /start.sh

# Exponer puerto y configurar entrada
EXPOSE 7860
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s \
    CMD curl --fail http://localhost:7860 || exit 1

CMD ["/start.sh"]
