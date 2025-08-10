FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

# Build arguments
ARG VLLM_INSTALL_TYPE=standard

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
# Pip optimizations
ENV PIP_NO_CACHE_DIR=1
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_DEFAULT_TIMEOUT=1000

# Install system dependencies required for pyenv and nginx
RUN echo 'Acquire::http::Pipeline-Depth "50";' >> /etc/apt/apt.conf.d/99parallel && \
    echo 'APT::Acquire::Retries "3";' >> /etc/apt/apt.conf.d/99parallel && \
    apt-get update && apt-get install -y \
    make \
    build-essential \
    libssl-dev \
    zlib1g-dev \
    libbz2-dev \
    libreadline-dev \
    libsqlite3-dev \
    wget \
    curl \
    llvm \
    libncurses5-dev \
    libncursesw5-dev \
    xz-utils \
    tk-dev \
    libffi-dev \
    liblzma-dev \
    git \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

    
    # Install pyenv
    RUN git clone https://github.com/pyenv/pyenv.git /opt/pyenv
    
    # Set environment variables for pyenv
    ENV PYENV_ROOT="/opt/pyenv"
    ENV PATH="$PYENV_ROOT/bin:$PATH"
    
    # Initialize pyenv in shell
    RUN echo 'eval "$(pyenv init -)"' >> ~/.bashrc
    
    # Install Python 3.12 via pyenv
    RUN eval "$(pyenv init -)" && pyenv install 3.12.0 && pyenv global 3.12.0
    
# Create symbolic links for python and pip to use Python 3.12 from pyenv
RUN ln -sf /opt/pyenv/versions/3.12.0/bin/python3 /usr/bin/python3
RUN ln -sf /opt/pyenv/versions/3.12.0/bin/python3 /usr/bin/python
RUN ln -sf /opt/pyenv/versions/3.12.0/bin/pip3 /usr/bin/pip3
RUN ln -sf /opt/pyenv/versions/3.12.0/bin/pip3 /usr/bin/pip

# Upgrade pip
RUN /opt/pyenv/versions/3.12.0/bin/python3 -m pip install --upgrade pip

# Install uv first using pyenv python
RUN /opt/pyenv/versions/3.12.0/bin/pip install uv

# Create virtual environment using uv with pip seeded
RUN /opt/pyenv/versions/3.12.0/bin/uv venv /opt/venv --python /opt/pyenv/versions/3.12.0/bin/python3 --seed

# Install uv in the virtual environment
RUN /opt/venv/bin/pip install uv

# Install PyTorch with CUDA support using uv (vLLM likes this)
RUN /opt/venv/bin/uv pip install --no-cache-dir \
--python /opt/venv/bin/python \
torch --index-url https://download.pytorch.org/whl/cu124

# Install vLLM and related dependencies 
RUN if [ "$VLLM_INSTALL_TYPE" = "gptoss" ]; then \
echo "Installing GPT-OSS vLLM..." && \
/opt/venv/bin/uv pip install --no-cache-dir --pre \
--python /opt/venv/bin/python \
vllm==0.10.1+gptoss \
--extra-index-url https://wheels.vllm.ai/gpt-oss/ \
--extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
--index-strategy unsafe-best-match \
"transformers>=4.35.0" accelerate safetensors numpy pyyaml uvicorn fastapi python-dotenv; \

else \
echo "Installing standard vLLM..." && \
/opt/venv/bin/uv pip install --no-cache-dir \
--python /opt/venv/bin/python \
vllm "transformers>=4.35.0" accelerate safetensors numpy pyyaml uvicorn fastapi python-dotenv; \
fi

# Prepare nginx runtime directories to avoid startup errors
RUN mkdir -p /var/log/nginx /var/cache/nginx /run/nginx && \
chown -R root:root /var/log/nginx /var/cache/nginx /run/nginx

# Create working directory
WORKDIR /app

# Expose ports for vLLM instances (8000-8010 for dynamic instances) and nginx
EXPOSE 8000-8010 80

# Copy all scripts
COPY scripts/ /app/scripts/

# (Optional: copy .env if you want it baked into the image; omit for secrets)
COPY .env /app/.env

# Make scripts executable
RUN chmod +x /app/scripts/vllm_launcher.py

# Default command launches dynamic vLLM + nginx orchestrator
CMD ["python", "/app/scripts/vllm_launcher.py"]
