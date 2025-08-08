# Balanced vLLM Docker

A dynamic, GPU-aware vLLM deployment system that automatically detects your hardware and scales across multiple GPUs with intelligent load balancing.

## 🚀 Features

- **🎯 Automatic GPU Detection**: Detects all available NVIDIA GPUs using `nvidia-smi`
- **⚖️ Intelligent Load Balancing**: Nginx automatically distributes requests across all instances
- **🔧 Flexible Deployment Strategies**: 
  - `multi_instance`: One vLLM instance per GPU (better for multiple users)
  - `tensor_parallel`: Single instance using all GPUs (better for large models)
- **🔄 Dynamic Scaling**: Automatically scales from 1 to N GPUs based on your hardware
- **🛠️ Dual vLLM Support**: Choose between standard vLLM or GPT-OSS optimized version
- **📝 Environment-based Configuration**: All settings via simple environment variables

## 🏗️ System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Your Client   │───▶│  Nginx (Port 80) │───▶│  Load Balancer  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                       ┌────────────────────────────────┼────────────────────────────────┐
                       ▼                                ▼                                ▼
              ┌─────────────────┐              ┌─────────────────┐              ┌─────────────────┐
              │ vLLM Instance 1 │              │ vLLM Instance 2 │              │ vLLM Instance N │
              │   (GPU 0)       │              │   (GPU 1)       │              │   (GPU N-1)     │
              │   Port 8000     │              │   Port 8001     │              │   Port 800N     │
              └─────────────────┘              └─────────────────┘              └─────────────────┘
```

## 🚀 Quick Start

### 1. Clone and Configure
```bash
git clone <repository>
cd balanced-vllm-docker

# Copy configuration template
cp .env.example .env
```

### 2. Edit Configuration
```bash
# Edit .env with your desired settings
nano .env
```

### 3. Start the System
```bash
# Build and start all containers
docker-compose up -d

# View logs
docker-compose logs -f
```

### 4. Test the Setup
```bash
# Test load balancer health
curl http://localhost/health

# Test model inference
curl -X POST http://localhost/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model-name", 
    "prompt": "The capital of France is", 
    "max_tokens": 50
  }'

# Check available models
curl http://localhost/v1/models
```

## ⚙️ Configuration Options

### Core Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_MODEL` | `facebook/opt-125m` | Hugging Face model to serve |
| `VLLM_MODEL_NAME` | `opt-125m` | Name for the served model (used in API responses) |
| `VLLM_STRATEGY` | `multi_instance` | Deployment strategy (`multi_instance` or `tensor_parallel`) |
| `VLLM_INSTALL_TYPE` | `standard` | vLLM installation (`standard` or `gptoss`) |

### Advanced Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `VLLM_GPU_COUNT` | auto-detect | Override number of GPUs to use |
| `VLLM_HOST` | `0.0.0.0` | Host to bind vLLM servers |
| `VLLM_BASE_PORT` | `8000` | Starting port number |
| `VLLM_MAX_MODEL_LEN` | `2048` | Maximum sequence length |
| `VLLM_GPU_MEMORY_UTILIZATION` | `0.80` | GPU memory usage fraction (0.1-0.95) |
| `HF_TOKEN` | - | Hugging Face token for gated/private models |

## 📋 Configuration Examples

### Basic Setup
```bash
# .env
VLLM_MODEL=microsoft/DialoGPT-medium
VLLM_MODEL_NAME=dialogue
VLLM_STRATEGY=multi_instance
```

### Large Model with Tensor Parallelism
```bash
# .env
VLLM_MODEL=meta-llama/Llama-2-13b-chat-hf
VLLM_MODEL_NAME=llama-13b
VLLM_STRATEGY=tensor_parallel
VLLM_MAX_MODEL_LEN=4096
VLLM_GPU_MEMORY_UTILIZATION=0.95
HF_TOKEN=your_hugging_face_token
```

### GPT-OSS High Performance
```bash
# .env
VLLM_INSTALL_TYPE=gptoss
VLLM_MODEL=openai/gpt-oss-20b
VLLM_MODEL_NAME=gpt-oss-20b
VLLM_STRATEGY=tensor_parallel
VLLM_MAX_MODEL_LEN=8192
```

### Development with Limited GPUs
```bash
# .env
VLLM_MODEL=facebook/opt-350m
VLLM_MODEL_NAME=opt-350m
VLLM_GPU_COUNT=1
VLLM_STRATEGY=multi_instance
```

### Production Multi-GPU Setup
```bash
# .env
VLLM_MODEL=mistralai/Mistral-7B-Instruct-v0.2
VLLM_MODEL_NAME=mistral-7b
VLLM_STRATEGY=multi_instance
VLLM_GPU_MEMORY_UTILIZATION=0.85
VLLM_MAX_MODEL_LEN=4096
HF_TOKEN=your_token_here
```

## 🎯 Deployment Strategies

### Multi-Instance Strategy (`multi_instance`)
- **Best for**: Multiple concurrent users, fault tolerance
- **Behavior**: Creates one vLLM instance per GPU
- **GPU Usage**: Each instance uses one GPU (`CUDA_VISIBLE_DEVICES=N`)
- **Access Patterns**:
  - Load balanced: `http://localhost/v1/completions`
  - Specific instance: `http://localhost/v1/your-model-1/completions`

### Tensor Parallel Strategy (`tensor_parallel`)
- **Best for**: Large models requiring multiple GPUs
- **Behavior**: Single vLLM instance using all GPUs with tensor parallelism
- **GPU Usage**: All GPUs used by single process (`CUDA_VISIBLE_DEVICES=0,1,2,...`)
- **Access Patterns**: `http://localhost/v1/completions`

## 🔧 vLLM Installation Types

### Standard vLLM (`VLLM_INSTALL_TYPE=standard`)
- **Default installation** from PyPI
- **Command**: `python -m vllm.entrypoints.openai.api_server`
- **Best for**: General use cases, stable releases

### GPT-OSS vLLM (`VLLM_INSTALL_TYPE=gptoss`)
- **Optimized version** with enhanced performance
- **Command**: `vllm serve`
- **Best for**: High-performance deployments, cutting-edge features
- **Installation**: Uses `uv` package manager with specialized index

## 📊 API Usage Examples

### OpenAI-Compatible Completions
```bash
curl -X POST http://localhost/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model",
    "prompt": "Explain quantum computing in simple terms:",
    "max_tokens": 100,
    "temperature": 0.7
  }'
```

### Chat Completions
```bash
curl -X POST http://localhost/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ],
    "max_tokens": 50
  }'
```

### Streaming Response
```bash
curl -X POST http://localhost/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "your-model",
    "prompt": "Write a short story about:",
    "max_tokens": 200,
    "stream": true
  }'
```

## 🔍 Monitoring and Troubleshooting

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f vllm
docker-compose logs -f nginx
```

### Check GPU Usage
```bash
# Real-time GPU monitoring
watch nvidia-smi

# Inside container
docker-compose exec vllm nvidia-smi
```

### Health Checks
```bash
# System health
curl http://localhost/health

# Available models
curl http://localhost/v1/models

# Container status
docker-compose ps
```

### Debug GPU Detection
```bash
# Run GPU detection manually
docker-compose exec vllm python -c "
import subprocess
result = subprocess.run(['nvidia-smi', '--list-gpus'], capture_output=True, text=True)
print('GPUs found:', len([l for l in result.stdout.strip().split('\\n') if l]))
print(result.stdout)
"
```

## 🛠️ Building with Different vLLM Versions

### Standard vLLM Build
```bash
docker-compose build
# or explicitly
VLLM_INSTALL_TYPE=standard docker-compose build
```

### GPT-OSS vLLM Build
```bash
VLLM_INSTALL_TYPE=gptoss docker-compose build
```

### Force Rebuild
```bash
docker-compose build --no-cache
```

## 🔒 Authentication for Private Models

### Using Hugging Face Token
```bash
# 1. Get token from https://huggingface.co/settings/tokens
# 2. Add to .env
echo "HF_TOKEN=hf_your_token_here" >> .env

# 3. Use gated model
echo "VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf" >> .env
```

### Login Alternative (for development)
```bash
# Inside container
docker-compose exec vllm huggingface-cli login
```

## 🚀 Performance Tuning

### Memory Optimization
```bash
# .env
VLLM_GPU_MEMORY_UTILIZATION=0.95  # Use more GPU memory
VLLM_MAX_MODEL_LEN=8192          # Longer sequences
```

### Multi-GPU Scaling
```bash
# Force use specific number of GPUs
VLLM_GPU_COUNT=4
VLLM_STRATEGY=multi_instance
```

### Load Balancing Tuning
The nginx configuration automatically optimizes for:
- Round-robin load balancing
- Connection keep-alive
- Proper timeouts for long-running inference
- Health checks and automatic failover

## 🔄 Scaling Examples

### 2 GPUs (Your Current Setup)
```bash
# Automatic detection creates:
# - Instance 1: GPU 0, Port 8000
# - Instance 2: GPU 1, Port 8001
# - Load balancer distributes between both
```

### 4 GPUs
```bash
VLLM_GPU_COUNT=4  # or auto-detected
VLLM_STRATEGY=multi_instance

# Creates:
# - Instance 1: GPU 0, Port 8000
# - Instance 2: GPU 1, Port 8001
# - Instance 3: GPU 2, Port 8002
# - Instance 4: GPU 3, Port 8003
```

### 8 GPUs with Large Model
```bash
VLLM_GPU_COUNT=8
VLLM_STRATEGY=tensor_parallel
VLLM_MODEL=meta-llama/Llama-2-70b-chat-hf

# Creates:
# - Single instance using all 8 GPUs
# - Tensor parallelism across GPUs
# - Single endpoint with massive model capacity
```

## 🆘 Common Issues and Solutions

### Container Startup Issues
```bash
# Check if GPUs are available
nvidia-smi

# Verify Docker has GPU access
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu20.04 nvidia-smi
```

### Model Loading Errors
```bash
# Check if model exists and you have access
# For private models, ensure HF_TOKEN is set
# Check model compatibility with vLLM
```

### Port Conflicts
```bash
# Change base port if 8000-8010 are busy
VLLM_BASE_PORT=9000
```

### Memory Issues
```bash
# Reduce GPU memory usage
VLLM_GPU_MEMORY_UTILIZATION=0.7

# Reduce model context length
VLLM_MAX_MODEL_LEN=1024
```

## 📖 API Documentation

The system provides a fully OpenAI-compatible API. Access the interactive documentation at:
- **Swagger UI**: `http://localhost/docs` (when available)
- **OpenAPI spec**: `http://localhost/openapi.json`

### Supported Endpoints
- `GET /v1/models` - List available models
- `POST /v1/completions` - Text completion
- `POST /v1/chat/completions` - Chat completion
- `GET /health` - Health check

### Load Balancing Behavior
- **Default route** (`/v1/*`): Round-robin across all instances
- **Instance-specific** (`/v1/model-name-1/*`): Direct to specific instance
- **Health monitoring**: Automatic failover if instance becomes unhealthy

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with different GPU configurations
5. Submit a pull request

## 📄 License

[Your License Here]

## 🙏 Acknowledgments

- [vLLM Team](https://github.com/vllm-project/vllm) for the excellent inference engine
- [NVIDIA](https://developer.nvidia.com/) for CUDA and container runtime
- [Hugging Face](https://huggingface.co/) for model hosting and transformers