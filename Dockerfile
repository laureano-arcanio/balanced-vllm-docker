FROM nvidia/cuda:12.9.1-runtime-ubuntu24.04

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

# Upgrade pip for Python 3.12
RUN /opt/pyenv/versions/3.12.0/bin/python3 -m pip install --upgrade pip

# Create initial virtual environments using pyenv Python
RUN /opt/pyenv/versions/3.12.0/bin/python3 -m venv /opt/venv1
RUN /opt/pyenv/versions/3.12.0/bin/python3 -m venv /opt/venv2

# Install PyTorch with CUDA support in the two venvs
RUN /opt/venv1/bin/pip install --upgrade pip && \
    /opt/venv1/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN /opt/venv2/bin/pip install --upgrade pip && \
    /opt/venv2/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install vLLM and related dependencies in the two venvs
RUN /opt/venv1/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn
RUN /opt/venv2/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn

# Create working directory
WORKDIR /app

# Expose ports for vLLM instances (8000-8010 range)
EXPOSE 8000-8010

# Copy only the valid scripts for the two instances
COPY start_vllm_instance1.sh /app/
COPY start_vllm_instance2.sh /app/

# Default command (can be overridden)
CMD ["bash"]
