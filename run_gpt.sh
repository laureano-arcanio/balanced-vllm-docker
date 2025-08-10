
# run command
docker run --gpus all --rm -it \
  -e VLLM_MODEL=openai/gpt-oss-20b \
  -e VLLM_MODEL_NAME=gpt-oss \
  -e VLLM_STRATEGY=multi_instance \
  -e VLLM_HOST=0.0.0.0 \
  -e VLLM_BASE_PORT=8000 \
  -e VLLM_MAX_MODEL_LEN=2048 \
  -e VLLM_GPU_MEMORY_UTILIZATION=0.9 \
  -e VLLM_INSTALL_TYPE=gptoss \
  -e MODEL_CACHE_PATH=/home/user/ai-models \
  -v ./models:/root/.cache/huggingface \
  -p 80:80 \
  -p 8000-8010:8000-8010 \
  balanced-vllm:latest \
  python /app/scripts/vllm_launcher.py