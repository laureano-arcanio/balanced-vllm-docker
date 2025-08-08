#!/usr/bin/env python3
"""
Dynamic vLLM Launcher
Automatically configures vLLM based on available GPUs and environment variables
"""
import os
import sys
import json
import subprocess
import time
import signal
from typing import List, Dict, Optional

class VLLMLauncher:
    def __init__(self):
        self.load_config()
        self.gpus = self.detect_gpus()
        self.processes = []
        
    def load_config(self):
        """Load configuration from environment variables"""
        self.model = os.getenv('VLLM_MODEL', 'facebook/opt-125m')
        self.model_name = os.getenv('VLLM_MODEL_NAME', 'default')
        self.strategy = os.getenv('VLLM_STRATEGY', 'multi_instance').lower()
        self.host = os.getenv('VLLM_HOST', '0.0.0.0')
        self.base_port = int(os.getenv('VLLM_BASE_PORT', '8000'))
        self.max_model_len = int(os.getenv('VLLM_MAX_MODEL_LEN', '2048'))
        self.gpu_memory_utilization = float(os.getenv('VLLM_GPU_MEMORY_UTILIZATION', '0.80'))
        self.gpu_count_override = os.getenv('VLLM_GPU_COUNT')
        self.vllm_install_type = os.getenv('VLLM_INSTALL_TYPE', 'standard').lower()
        
        if self.gpu_count_override:
            self.gpu_count_override = int(self.gpu_count_override)
        
        print(f"Configuration loaded:")
        print(f"  Model: {self.model}")
        print(f"  Model Name: {self.model_name}")
        print(f"  Strategy: {self.strategy}")
        print(f"  vLLM Install Type: {self.vllm_install_type}")
        print(f"  GPU Count Override: {self.gpu_count_override}")
    
    def detect_gpus(self) -> List[Dict]:
        """Detect available GPUs using nvidia-smi"""
        try:
            result = subprocess.run([
                'nvidia-smi', 
                '--query-gpu=index,name,memory.total,memory.free',
                '--format=csv,noheader,nounits'
            ], capture_output=True, text=True, check=True)
            
            gpus = []
            for line in result.stdout.strip().split('\n'):
                if line:
                    parts = [p.strip() for p in line.split(',')]
                    gpus.append({
                        'index': int(parts[0]),
                        'name': parts[1],
                        'memory_total': int(parts[2]) // 1024,  # Convert MB to GB
                        'memory_free': int(parts[3]) // 1024    # Convert MB to GB
                    })
            
            # Apply GPU count override if specified
            if self.gpu_count_override and self.gpu_count_override < len(gpus):
                gpus = gpus[:self.gpu_count_override]
            
            print(f"Detected {len(gpus)} GPU(s):")
            for gpu in gpus:
                print(f"  GPU {gpu['index']}: {gpu['name']} ({gpu['memory_total']}GB)")
            
            return gpus
            
        except subprocess.CalledProcessError as e:
            print(f"Error detecting GPUs: {e}")
            sys.exit(1)
        except Exception as e:
            print(f"Error parsing GPU information: {e}")
            sys.exit(1)
    
    def launch_multi_instance(self):
        """Launch one vLLM instance per GPU"""
        print(f"\\nLaunching {len(self.gpus)} vLLM instances (multi-instance strategy)...")
        
        for i, gpu in enumerate(self.gpus):
            port = self.base_port + i
            gpu_id = gpu['index']
            instance_name = f"{self.model_name}-{i+1}"
            
            # Choose the appropriate vLLM command based on install type
            if self.vllm_install_type == 'gptoss':
                # Use vllm serve command for GPT-OSS
                cmd = [
                    '/opt/venv/bin/vllm', 'serve',
                    self.model,
                    '--host', self.host,
                    '--port', str(port),
                    '--served-model-name', instance_name,
                    '--max-model-len', str(self.max_model_len),
                    '--gpu-memory-utilization', str(self.gpu_memory_utilization),
                    '--tensor-parallel-size', '1'
                ]
            else:
                # Use standard python -m vllm.entrypoints.openai.api_server
                cmd = [
                    '/opt/venv/bin/python', '-m', 'vllm.entrypoints.openai.api_server',
                '--model', self.model,
                '--host', self.host,
                '--port', str(port),
                '--served-model-name', instance_name,
                    '--max-model-len', str(self.max_model_len),
                    '--gpu-memory-utilization', str(self.gpu_memory_utilization),
                    '--tensor-parallel-size', '1'
                ]
            
            env = os.environ.copy()
            env['CUDA_VISIBLE_DEVICES'] = str(gpu_id)
            
            print(f"  Starting instance {i+1} on GPU {gpu_id}, port {port}")
            print(f"    Model: {instance_name}")
            print(f"    Command: {' '.join(cmd)}")
            
            process = subprocess.Popen(cmd, env=env)
            self.processes.append({
                'process': process,
                'gpu_id': gpu_id,
                'port': port,
                'instance_name': instance_name
            })
            
            # Small delay between starts
            time.sleep(2)
    
    def launch_tensor_parallel(self):
        """Launch single vLLM instance using all GPUs with tensor parallelism"""
        gpu_ids = [str(gpu['index']) for gpu in self.gpus]
        tensor_parallel_size = len(self.gpus)
        
        print(f"\\nLaunching single vLLM instance (tensor-parallel strategy)...")
        print(f"  Using GPUs: {', '.join(gpu_ids)}")
        print(f"  Tensor parallel size: {tensor_parallel_size}")
        
        # Choose the appropriate vLLM command based on install type
        if self.vllm_install_type == 'gptoss':
            # Use vllm serve command for GPT-OSS
            cmd = [
                '/opt/venv/bin/vllm', 'serve',
                self.model,
                '--host', self.host,
                '--port', str(self.base_port),
                '--served-model-name', self.model_name,
                '--max-model-len', str(self.max_model_len),
                '--gpu-memory-utilization', str(self.gpu_memory_utilization),
                '--tensor-parallel-size', str(tensor_parallel_size)
            ]
        else:
            # Use standard python -m vllm.entrypoints.openai.api_server
            cmd = [
                '/opt/venv/bin/python', '-m', 'vllm.entrypoints.openai.api_server',
                '--model', self.model,
                '--host', self.host,
                '--port', str(self.base_port),
                '--served-model-name', self.model_name,
                '--max-model-len', str(self.max_model_len),
                '--gpu-memory-utilization', str(self.gpu_memory_utilization),
                '--tensor-parallel-size', str(tensor_parallel_size)
            ]
        
        env = os.environ.copy()
        env['CUDA_VISIBLE_DEVICES'] = ','.join(gpu_ids)
        
        print(f"    Command: {' '.join(cmd)}")
        
        process = subprocess.Popen(cmd, env=env)
        self.processes.append({
            'process': process,
            'gpu_id': ','.join(gpu_ids),
            'port': self.base_port,
            'instance_name': self.model_name
        })
    
    def generate_nginx_config(self):
        """Generate nginx configuration based on launched instances"""
        if self.strategy == 'multi_instance':
            upstreams = []
            locations = []
            backends = []
            
            for i, proc_info in enumerate(self.processes):
                port = proc_info['port']
                instance_name = proc_info['instance_name']
                
                # Individual instance upstream
                upstreams.append(f"""upstream {instance_name} {{
    server localhost:{port};
}}""")
                
                # Individual instance location
                locations.append(f"""    # Route to {instance_name}
    location /v1/{instance_name}/ {{
        rewrite ^/v1/{instance_name}/(.*) /v1/$1 break;
        proxy_pass http://{instance_name};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }}""")
                
                backends.append(f"        server localhost:{port};")
            
            # Load balancer upstream
            upstreams.append(f"""upstream vllm_backends {{
{chr(10).join(backends)}
}}""")
            
            # Load balancer location
            locations.append("""    # Load balancing for /v1/ path
    location /v1/ {
        proxy_pass http://vllm_backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }""")
            
        else:  # tensor_parallel
            port = self.base_port
            upstreams = [f"""upstream vllm_backends {{
    server localhost:{port};
}}"""]
            
            locations = [f"""    # Single instance with tensor parallelism
    location /v1/ {{
        proxy_pass http://vllm_backends;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }}"""]
        
        nginx_config = f"""events {{
    worker_connections 1024;
}}

http {{
{chr(10).join(upstreams)}

    server {{
        listen 80;
        server_name localhost;

{chr(10).join(locations)}

        # Health check endpoint
        location /health {{
            access_log off;
            return 200 "healthy\\n";
            add_header Content-Type text/plain;
        }}

        # Default route
        location / {{
            proxy_pass http://vllm_backends;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 300s;
            proxy_connect_timeout 75s;
        }}
    }}
}}"""
        
        # Write the config to shared volume (nginx.conf in the shared directory)
        nginx_config_path = '/tmp/nginx.conf'
        with open(nginx_config_path, 'w') as f:
            f.write(nginx_config)
        
        print(f"\\nGenerated nginx configuration at /tmp/nginx.conf")
        print("Instance summary:")
        for proc_info in self.processes:
            print(f"  - {proc_info['instance_name']}: GPU {proc_info['gpu_id']}, port {proc_info['port']}")
    
    def launch(self):
        """Main launch method"""
        if not self.gpus:
            print("No GPUs detected!")
            sys.exit(1)
        
        if self.strategy == 'multi_instance':
            self.launch_multi_instance()
        elif self.strategy == 'tensor_parallel':
            self.launch_tensor_parallel()
        else:
            print(f"Unknown strategy: {self.strategy}")
            sys.exit(1)
        
        self.generate_nginx_config()
        
        # Setup signal handlers
        def signal_handler(signum, frame):
            print("\\nShutting down vLLM instances...")
            for proc_info in self.processes:
                proc_info['process'].terminate()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Wait for all processes
        print("\\nvLLM instances are starting up...")
        print("Press Ctrl+C to shutdown")
        
        try:
            while True:
                # Check if any process has died
                for proc_info in self.processes:
                    if proc_info['process'].poll() is not None:
                        print(f"Instance {proc_info['instance_name']} has stopped!")
                        return proc_info['process'].returncode
                time.sleep(5)
        except KeyboardInterrupt:
            signal_handler(signal.SIGINT, None)

if __name__ == "__main__":
    launcher = VLLMLauncher()
    sys.exit(launcher.launch())