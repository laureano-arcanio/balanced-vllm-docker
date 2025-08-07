FROM nvidia/cuda:12.9.1-runtime-ubuntu24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install system dependencies and add deadsnakes PPA for Python 3.12
RUN apt-get update && apt-get install -y \
    software-properties-common \
    git \
    wget \
    curl \
    build-essential \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y \
    python3.12 \
    python3.12-dev \
    python3.12-venv \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && rm -rf /var/lib/apt/lists/*

# Create symbolic links for python and pip to use Python 3.12
RUN ln -sf /usr/bin/python3.12 /usr/bin/python3
RUN ln -sf /usr/bin/python3.12 /usr/bin/python
RUN ln -sf /usr/bin/pip3.12 /usr/bin/pip3
RUN ln -sf /usr/bin/pip3.12 /usr/bin/pip

# Upgrade pip for Python 3.12
RUN python3.12 -m pip install --upgrade pip

# Create initial virtual environments (more can be created dynamically)
RUN python3.12 -m venv /opt/venv1
RUN python3.12 -m venv /opt/venv2
RUN python3.12 -m venv /opt/venv3
RUN python3.12 -m venv /opt/venv4

# Install PyTorch with CUDA support in all venvs
RUN /opt/venv1/bin/pip install --upgrade pip && \
    /opt/venv1/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN /opt/venv2/bin/pip install --upgrade pip && \
    /opt/venv2/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN /opt/venv3/bin/pip install --upgrade pip && \
    /opt/venv3/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

RUN /opt/venv4/bin/pip install --upgrade pip && \
    /opt/venv4/bin/pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Install vLLM and related dependencies in all venvs
RUN /opt/venv1/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn
RUN /opt/venv2/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn
RUN /opt/venv3/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn
RUN /opt/venv4/bin/pip install vllm[all] transformers accelerate datasets sentencepiece protobuf fastapi uvicorn

# Create working directory
WORKDIR /app

# Expose ports for vLLM instances (8000-8010 range)
EXPOSE 8000-8010

# Copy only the valid scripts for the two instances
COPY start_vllm_instance1.sh /app/
COPY start_vllm_instance2.sh /app/

# Default command (can be overridden)
CMD ["bash"]
