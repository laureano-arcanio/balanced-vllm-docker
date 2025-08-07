#!/bin/bash

# Setup script to create multiple virtual environments based on configuration

CONFIG_FILE="/app/instances.config"
MAX_VENVS=4  # Maximum number of virtual environments to create

echo "Setting up virtual environments for vLLM instances..."

# Count unique instances to determine how many venvs we need
INSTANCE_COUNT=$(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | wc -l)
VENV_COUNT=$((INSTANCE_COUNT > MAX_VENVS ? MAX_VENVS : INSTANCE_COUNT))

echo "Creating $VENV_COUNT virtual environments for $INSTANCE_COUNT instances..."

# Create virtual environments
for i in $(seq 1 $VENV_COUNT); do
    VENV_PATH="/opt/venv$i"
    
    if [ ! -d "$VENV_PATH" ]; then
        echo "Creating virtual environment: $VENV_PATH"
        python3.12 -m venv "$VENV_PATH"
        
        source "$VENV_PATH/bin/activate"
        
        echo "Installing dependencies in $VENV_PATH..."
        pip install --upgrade pip
        pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
        pip install vllm[all] \
            transformers \
            accelerate \
            datasets \
            sentencepiece \
            protobuf \
            fastapi \
            uvicorn
        
        deactivate
        echo "Completed setup for $VENV_PATH"
    else
        echo "Virtual environment $VENV_PATH already exists, skipping..."
    fi
done

echo "Virtual environment setup complete!"

# Show which instances will use which venvs
echo ""
echo "Instance to Virtual Environment Mapping:"
while IFS=':' read -r NAME PORT MODEL DEVICE MAX_MODEL_LEN TENSOR_PARALLEL; do
    if [[ "$NAME" =~ ^#.*$ ]] || [[ -z "$NAME" ]]; then
        continue
    fi
    
    VENV_NUM=$(($(echo -n "$NAME" | cksum | cut -d' ' -f1) % VENV_COUNT + 1))
    echo "  $NAME -> /opt/venv$VENV_NUM"
done < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$')

echo ""
echo "Verifying Python versions:"
for i in $(seq 1 $VENV_COUNT); do
    if [ -d "/opt/venv$i" ]; then
        echo "  venv$i: $(/opt/venv$i/bin/python --version)"
    fi
done
