#!/bin/bash

# Activate virtual environment for instance 2
source /opt/venv2/bin/activate

# Start vLLM instance 2 on port 8001
echo "Starting vLLM instance 2 on port 8001 with venv2..."

# You can customize the model and other parameters here
python -m vllm.entrypoints.openai.api_server \
    --model microsoft/DialoGPT-small \
    --host 0.0.0.0 \
    --port 8001 \
    --served-model-name instance2 \
    --max-model-len 2048 \
    --tensor-parallel-size 1
