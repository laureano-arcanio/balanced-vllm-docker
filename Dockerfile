FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies required for pyenv
RUN apt-get update && apt-get install -y \
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

# Create initial virtual environments using pyenv Python
RUN /opt/pyenv/versions/3.12.0/bin/python3 -m venv /opt/venv

# Install PyTorch with CUDA support
RUN /opt/venv/bin/pip install --upgrade pip && \
    /opt/venv/bin/pip install torch --index-url https://download.pytorch.org/whl/cu124

# Install vLLM and related dependencies 
RUN /opt/venv/bin/pip install vllm "transformers>=4.35.0" accelerate safetensors numpy pyyaml uvicorn fastapi

# Create working directory
WORKDIR /app

# Expose ports for vLLM instances
EXPOSE 8000 8001


# Copy only the valid scripts for the two instances
COPY scripts/start_vllm_instance1.sh /app/
COPY scripts/start_vllm_instance2.sh /app/

# For multiple GPU instances, its more performant to use separate vLLM instances (added 2 for simplicity)
# When running on a single GPU, its more performant to use a single vLLM instance with tensor parallelism
# --tensor-parallel-size 1
RUN chmod +x /app/start_vllm_instance1.sh
RUN chmod +x /app/start_vllm_instance2.sh


# Default command (can be overridden)
CMD ["bash"]
