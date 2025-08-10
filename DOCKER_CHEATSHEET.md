# Docker Cheatsheet

## Why is GPU 0 receiving more load than GPU 1?

The issue of GPU 0 receiving more load than GPU 1 could be caused by several factors in your setup:

### 1. Default GPU Selection
If the environment variable `CUDA_VISIBLE_DEVICES` is not properly set for each vLLM instance, the default behavior is to use GPU 0.
- In your script, `CUDA_VISIBLE_DEVICES` is set for each instance, but ensure that it is correctly applied to all processes.

### 2. Uneven GPU Memory Utilization
The `--gpu-memory-utilization` parameter is set to `0.9` in your configuration. If GPU 0 has less free memory than GPU 1, it might be overloaded.
- Check the available memory on each GPU using `nvidia-smi` before launching the instances.

### 3. Process Scheduling
The `subprocess.Popen` calls in your script might not evenly distribute the load across GPUs.
- Ensure that each instance is correctly assigned to its respective GPU.

### 4. Tensor Parallelism
If you're using the `tensor_parallel` strategy, the load might not be evenly distributed across GPUs due to model-specific behavior or inefficiencies in tensor splitting.

---

## Debugging Steps

### Verify GPU Assignment
Add a debug print statement to confirm `CUDA_VISIBLE_DEVICES` is correctly set for each instance.

### Check GPU Memory
Use `nvidia-smi` to monitor memory usage on each GPU:
```bash
nvidia-smi
```

### Adjust `gpu_memory_utilization`
Lower the value (e.g., `0.8`) to reduce the load on GPU 0.

### Test Single GPU
Run the script with `VLLM_GPU_COUNT=1` to isolate the issue:
```bash
export VLLM_GPU_COUNT=1
python your_script.py
```

---

## Possible Fix

Ensure that the GPU assignment logic in your script is correctly applied. If the issue persists:
- Consider explicitly logging GPU usage and memory allocation for each instance.
```python
# Example: Log GPU usage
import torch
print(f"Using GPU: {torch.cuda.current_device()}, Memory Allocated: {torch.cuda.memory_allocated()}")
```

---

## Docker Commands

### Basic Commands
- List all running containers:
```bash
docker ps
```

- List all containers (including stopped ones):
```bash
docker ps -a
```

- Start a container:
```bash
docker start <container_id>
```

- Stop a container:
```bash
docker stop <container_id>
```

- Remove a container:
```bash
docker rm <container_id>
```

- Remove all stopped containers:
```bash
docker container prune
```

- Build an image from a Dockerfile:
```bash
docker build -t <image_name> .
```

- Run a container from an image:
```bash
docker run -it --name <container_name> <image_name>
```

- Remove an image:
```bash
docker rmi <image_id>
```

---

### GPU-Specific Commands
- Run a container with GPU support:
```bash
docker run --gpus all -it <image_name>
```

- Limit GPU usage to specific devices:
```bash
docker run --gpus '"device=0,1"' -it <image_name>
```

---

### Debugging and Monitoring
- Check logs of a container:
```bash
docker logs <container_id>
```

- Monitor resource usage of containers:
```bash
docker stats
```

- Inspect a container's details:
```bash
docker inspect <container_id>
```

---

### Networking
- List all networks:
```bash
docker network ls
```

- Create a new network:
```bash
docker network create <network_name>
```

- Connect a container to a network:
```bash
docker network connect <network_name> <container_id>
```

- Disconnect a container from a network:
```bash
docker network disconnect <network_name> <container_id>
```

---

### Volumes
- List all volumes:
```bash
docker volume ls
```

- Create a volume:
```bash
docker volume create <volume_name>
```

- Remove a volume:
```bash
docker volume rm <volume_name>
```

- Mount a volume to a container:
```bash
docker run -v <volume_name>:/path/in/container -it <image_name>
```

---

## vLLM Docker Run Example

### Complete Command with Model Caching
```bash
docker run --gpus all --rm -it \
  -e HF_TOKEN=<your_hf_token> \
  -e VLLM_MODEL=google/gemma-3-4b-it \
  -e VLLM_MODEL_NAME=gemma-3-4b-it \
  -e VLLM_STRATEGY=multi_instance \
  -e VLLM_GPU_COUNT=2 \
  -e VLLM_HOST=0.0.0.0 \
  -e VLLM_BASE_PORT=8000 \
  -e VLLM_MAX_MODEL_LEN=2048 \
  -e VLLM_GPU_MEMORY_UTILIZATION=0.9 \
  -e VLLM_INSTALL_TYPE=standard \
  -e MODEL_CACHE_PATH=./models \
  -v ./models:/root/.cache/huggingface \
  -p 8080:8080 \
  -p 8000-8010:8000-8010 \
  laureanoarcaino/balanced-vllm:latest \
  python /app/scripts/vllm_launcher.py
```

### How the Cache Mount Works
- -v host_path:container_path
- Here: ./models (host) -> /root/.cache/huggingface (container)
- ./models is resolved relative to the directory you run docker run from.
- If the directory does not exist Docker will create it (as root-owned). Prefer: mkdir -p models first.
- Hugging Face inside the container writes to /root/.cache/huggingface; those files persist in ./models on the host.
- MODEL_CACHE_PATH is an env var your app can read (set to ./models here). Inside the container it still points to the literal string ./models; if your code expects the in-container absolute path you can instead set:
  -e MODEL_CACHE_PATH=/root/.cache/huggingface
- To avoid ambiguity you can also use an absolute host path:
  -v "$(pwd)/models:/root/.cache/huggingface"

### Summary
Use -v ./models:/root/.cache/huggingface to persist model downloads locally in the ./models folder while the application reads/writes the standard Hugging Face cache path inside
