#!/bin/bash

# Script to manually set up virtual environments (optional for debugging)

echo "Setting up virtual environments with Python 3.12..."

# Create venv1 and install dependencies
echo "Creating venv1 with Python 3.12..."
python3.12 -m venv /opt/venv1
source /opt/venv1/bin/activate

echo "Installing PyTorch in venv1..."
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

echo "Installing vLLM and dependencies in venv1..."
pip install vllm[all] \
    transformers \
    accelerate \
    datasets \
    sentencepiece \
    protobuf \
    fastapi \
    uvicorn

deactivate

# Create venv2 and install dependencies
echo "Creating venv2 with Python 3.12..."
python3.12 -m venv /opt/venv2
source /opt/venv2/bin/activate

echo "Installing PyTorch in venv2..."
pip install --upgrade pip
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

echo "Installing vLLM and dependencies in venv2..."
pip install vllm[all] \
    transformers \
    accelerate \
    datasets \
    sentencepiece \
    protobuf \
    fastapi \
    uvicorn

deactivate

echo "Virtual environments setup complete with Python 3.12!"
echo "venv1 location: /opt/venv1"
echo "venv2 location: /opt/venv2"

# Verify Python versions
echo "Python version in venv1:"
/opt/venv1/bin/python --version
echo "Python version in venv2:"
/opt/venv2/bin/python --version
