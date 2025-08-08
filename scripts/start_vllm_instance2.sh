#!/bin/bash

# Limit GPU memory usage to 80%, this will depend on the server specs
export VLLM_MAX_GPU_MEMORY=0.80

source /opt/venv/bin/activate

# GPT-OSS models can be used with vLLM as well. Uncomment the following lines to use GPT-OSS.
# uv pip install --pre vllm==0.10.1+gptoss \
#     --extra-index-url https://wheels.vllm.ai/gpt-oss/ \
#     --extra-index-url https://download.pytorch.org/whl/nightly/cu128 \
#     --index-strategy unsafe-best-match

# CUDA_VISIBLE_DEVICES=1 vllm serve openai/gpt-oss-20b

# Start vLLM instance 2 on port 8001
echo "Starting vLLM instance 2 on port 8001 with venv..."

# You can customize the model and other parameters here
CUDA_VISIBLE_DEVICES=1 python -m vllm.entrypoints.openai.api_server \
    --model google/gemma-3-4b-it \
    --host 0.0.0.0 \
    --port 8001 \
    --served-model-name gemma3:4b \
    --max-model-len 2048 \
    --tensor-parallel-size 1
