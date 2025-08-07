#!/bin/bash

# Activate virtual environment for instance 1
source /opt/venv1/bin/activate

# Start vLLM instance 1 on port 8000
echo "Starting vLLM instance 1 on port 8000 with venv1..."

# You can customize the model and other parameters here
python -m vllm.entrypoints.openai.api_server \
    --model microsoft/DialoGPT-medium \
    --host 0.0.0.0 \
    --port 8000 \
    --served-model-name instance1 \
    --max-model-len 2048 \
    --tensor-parallel-size 1
