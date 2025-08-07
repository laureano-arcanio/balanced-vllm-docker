#!/bin/bash

# Dynamic instance starter script
# Reads configuration and starts the specified instance

if [ $# -ne 1 ]; then
    echo "Usage: $0 <instance_name>"
    echo "Available instances:"
    grep -v '^#' /app/instances.config | grep -v '^$' | cut -d':' -f1
    exit 1
fi

INSTANCE_NAME=$1
CONFIG_FILE="/app/instances.config"

# Read configuration for the specified instance
CONFIG_LINE=$(grep "^${INSTANCE_NAME}:" "$CONFIG_FILE")

if [ -z "$CONFIG_LINE" ]; then
    echo "Error: Instance '$INSTANCE_NAME' not found in configuration"
    exit 1
fi

# Parse configuration
IFS=':' read -r NAME PORT MODEL DEVICE MAX_MODEL_LEN TENSOR_PARALLEL <<< "$CONFIG_LINE"

echo "Starting vLLM instance: $NAME"
echo "Port: $PORT"
echo "Model: $MODEL"
echo "Device: $DEVICE"
echo "Max Model Length: $MAX_MODEL_LEN"
echo "Tensor Parallel Size: $TENSOR_PARALLEL"

# Determine virtual environment based on instance name
# Use hash of instance name to distribute across available venvs
VENV_NUM=$(($(echo -n "$INSTANCE_NAME" | cksum | cut -d' ' -f1) % $(ls -d /opt/venv* | wc -l) + 1))
VENV_PATH="/opt/venv${VENV_NUM}"

echo "Using virtual environment: $VENV_PATH"

# Activate the virtual environment
source "$VENV_PATH/bin/activate"

# Set CUDA device if specified
if [ "$DEVICE" != "auto" ] && [ "$DEVICE" != "cpu" ]; then
    export CUDA_VISIBLE_DEVICES=$DEVICE
    echo "CUDA_VISIBLE_DEVICES set to: $DEVICE"
elif [ "$DEVICE" = "cpu" ]; then
    export CUDA_VISIBLE_DEVICES=""
    echo "Running on CPU only"
else
    echo "Using automatic device selection"
fi

# Prepare vLLM command arguments
VLLM_ARGS=(
    --model "$MODEL"
    --host 0.0.0.0
    --port "$PORT"
    --served-model-name "$NAME"
    --max-model-len "$MAX_MODEL_LEN"
    --tensor-parallel-size "$TENSOR_PARALLEL"
)

# Add device-specific arguments
if [ "$DEVICE" = "cpu" ]; then
    VLLM_ARGS+=(--device cpu)
fi

# Start vLLM instance
echo "Executing: python -m vllm.entrypoints.openai.api_server ${VLLM_ARGS[*]}"
exec python -m vllm.entrypoints.openai.api_server "${VLLM_ARGS[@]}"
