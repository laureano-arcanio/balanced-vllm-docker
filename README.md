# vLLM Docker Setup

This Docker setup provides a reverse proxy to direct traffic to 2 different vLLM instances running on separate ports.

## Architecture

- **vLLM Instance 1**: Runs on port 8000 with `microsoft/DialoGPT-medium` in `/opt/venv1`
- **vLLM Instance 2**: Runs on port 8001 with `microsoft/DialoGPT-small` in `/opt/venv2`
- **Nginx Reverse Proxy**: Routes traffic on port 80

Each vLLM instance runs in its own isolated Python virtual environment for better dependency management and isolation.

## Prerequisites

- Docker and Docker Compose installed
- NVIDIA Docker runtime (for GPU support)
- At least 2 GPUs (or modify CUDA_VISIBLE_DEVICES for single GPU)

**Note**: This setup uses Python 3.12 for both vLLM instances, installed via the deadsnakes PPA.

## Quick Start

1. Build and start all services:
```bash
docker-compose up --build
```

2. Access the services:
- Instance 1: `http://localhost/v1/instance1/`
- Instance 2: `http://localhost/v1/instance2/`
- Default (Instance 1): `http://localhost/v1/`
- Health check: `http://localhost/health`

## Configuration

### Virtual Environments

Each vLLM instance runs in its own virtual environment:
- Instance 1: `/opt/venv1`
- Instance 2: `/opt/venv2`

This provides complete isolation between instances, allowing for:
- Different package versions if needed
- Independent dependency management
- Better resource isolation

### Routing Rules

The nginx reverse proxy routes traffic based on URL paths:
- `/v1/instance1/*` → vLLM Instance 1 (port 8000)
- `/v1/instance2/*` → vLLM Instance 2 (port 8001)
- `/v1/*` → vLLM Instance 1 (default)

### Model Configuration

Edit the startup scripts to change models:
- `scripts/start_vllm_instance1.sh` - Configure instance 1
- `scripts/start_vllm_instance2.sh` - Configure instance 2

### GPU Assignment

Modify `CUDA_VISIBLE_DEVICES` in `docker-compose.yml`:
- Instance 1: `CUDA_VISIBLE_DEVICES=0`
- Instance 2: `CUDA_VISIBLE_DEVICES=1`

For single GPU, use `CUDA_VISIBLE_DEVICES=0` for both.

## Usage Examples

### OpenAI-compatible API calls

Instance 1:
```bash
curl -X POST "http://localhost/v1/instance1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "instance1",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

Instance 2:
```bash
curl -X POST "http://localhost/v1/instance2/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "instance2",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Monitoring

Check service health:
```bash
# Overall health
curl http://localhost/health

# Individual instances
curl http://localhost:8000/health
curl http://localhost:8001/health
```

View logs:
```bash
# All services
docker-compose logs

# Specific service
docker-compose logs vllm1
docker-compose logs vllm2
docker-compose logs nginx
```

## Customization

### Customizing Virtual Environments

If you need different package versions for each instance:

1. Modify the Dockerfile to install different packages in each venv
2. Or use the `scripts/setup_venvs.sh` script for manual setup
3. Update startup scripts to activate the correct venv

Example for different vLLM versions:
```dockerfile
# In Dockerfile
RUN /opt/venv1/bin/pip install vllm==0.2.7
RUN /opt/venv2/bin/pip install vllm==0.3.0
```

### Adding More Instances

1. Add a new service in `docker-compose.yml`
2. Create a new startup script
3. Update `nginx.conf` with new routing rules

### Load Balancing

Modify `nginx.conf` to implement round-robin or other load balancing strategies between instances.

### HTTPS Support

Add SSL certificates and update nginx configuration for HTTPS support.

## Troubleshooting

1. **GPU Issues**: Ensure NVIDIA Docker runtime is installed
2. **Memory Issues**: Adjust `--max-model-len` in startup scripts
3. **Port Conflicts**: Change ports in `docker-compose.yml` if needed
4. **Model Download**: First run may take time to download models
5. **Python Version**: Verify Python 3.12 is being used with `scripts/verify_python.sh`

## Stopping Services

```bash
docker-compose down
```

To remove volumes as well:
```bash
docker-compose down -v
```

## Dynamic Server Enabling/Disabling

### Overview
The Nginx configuration allows dynamic enabling or disabling of backend servers using variables. This is achieved through the `map` directive in the `nginx.conf` file.

### Configuration Details

1. **Variable Definition**:
   The `$enable_vllm2` variable is used to control which backend server is active. It is defined in the `map` block:
   ```nginx
   map $enable_vllm2 $vllm_backend {
       default vllm1:8000;
       1       vllm2:8001;
   }
   ```

2. **Dynamic Behavior**:
   - When `$enable_vllm2` is set to `1`, requests to `/v1/` are routed to `vllm2` (port 8001).
   - By default, requests are routed to `vllm1` (port 8000).

3. **Setting the Variable**:
   - The variable can be set in the Nginx configuration using the `set` directive:
     ```nginx
     set $enable_vllm2 1;
     ```
   - Alternatively, it can be passed as an environment variable when running the Nginx container:
     ```bash
     docker run -e enable_vllm2=1 nginx
     ```

4. **Example Use Case**:
   - Enable `vllm2` for specific conditions, such as maintenance or testing.
   - Use the `if` directive to dynamically set the variable based on request headers or other conditions:
     ```nginx
     if ($http_x_enable_vllm2 = "true") {
         set $enable_vllm2 1;
     }
     ```

### Testing the Configuration

1. Start the services:
   ```bash
   docker-compose up --build
   ```

2. Test routing:
   - Default behavior (routes to `vllm1`):
     ```bash
     curl http://localhost/v1/
     ```
   - Enable `vllm2` and test:
     ```bash
     docker exec -it <nginx-container-id> bash
     echo "set $enable_vllm2 1;" >> /etc/nginx/nginx.conf
     nginx -s reload
     curl http://localhost/v1/
     ```

3. Verify logs to confirm routing:
   ```bash
   docker-compose logs nginx
   ```
