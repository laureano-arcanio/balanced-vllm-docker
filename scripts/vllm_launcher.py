#!/usr/bin/env python3
"""
Dynamic vLLM Launcher
Automatically configures vLLM based on available GPUs and environment variables
"""
import os
import sys
import subprocess
import time
import signal
from typing import List, Dict
import socket  # added for readiness check
import urllib.request
import json

class VLLMLauncher:
    def __init__(self):
        self.load_config()
        self.gpus = self.detect_gpus()
        self.processes = []
        
    def load_config(self):
        """Load configuration from environment variables"""
        self.model = os.getenv('VLLM_MODEL', 'google/gemma-3-1b-it')
        self.model_name = os.getenv('VLLM_MODEL_NAME', 'default')
        self.strategy = os.getenv('VLLM_STRATEGY', 'multi_instance').lower()
        self.host = os.getenv('VLLM_HOST', '0.0.0.0')
        self.base_port = int(os.getenv('VLLM_BASE_PORT', '8000'))
        self.max_model_len = int(os.getenv('VLLM_MAX_MODEL_LEN', '2048'))
        self.gpu_memory_utilization = float(os.getenv('VLLM_GPU_MEMORY_UTILIZATION', '0.90'))
        self.gpu_count_override = os.getenv('VLLM_GPU_COUNT')
        self.vllm_install_type = os.getenv('VLLM_INSTALL_TYPE', 'standard').lower()
        self.model_cache_path = os.getenv('MODEL_CACHE_PATH', './models')
        self.nginx_port = int(os.getenv('NGINX_PORT', '80'))
        
        if self.gpu_count_override:
            self.gpu_count_override = int(self.gpu_count_override)
        
        print("Configuration loaded:")
        print(f"  Model: {self.model}")
        print(f"  Model Name: {self.model_name}")
        print(f"  Strategy: {self.strategy}")
        print(f"  vLLM Install Type: {self.vllm_install_type}")
        print(f"  GPU Count Override: {self.gpu_count_override}")
        print(f"  Model Cache Path: {self.model_cache_path}")
        print(f"  Nginx Port: {self.nginx_port}")

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
        print(f"[multi-instance] Starting launch_multi_instance method")
        print(f"[multi-instance] GPU count: {len(self.gpus)}")
        print(f"[multi-instance] Strategy: {self.strategy}")
        print(f"\\nLaunching {len(self.gpus)} vLLM instances (multi-instance strategy)...")
        
        for i, gpu in enumerate(self.gpus):
            port = self.base_port + i
            gpu_id = gpu['index']
            
            # Choose the appropriate vLLM command based on install type
            if self.vllm_install_type == 'gptoss':
                # Use vllm serve command for GPT-OSS
                cmd = [
                    '/opt/venv/bin/vllm', 'serve',
                    self.model,
                    '--host', self.host,
                    '--port', str(port),
                    '--served-model-name', self.model_name,
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
                '--served-model-name', self.model_name,
                    '--max-model-len', str(self.max_model_len),
                    '--gpu-memory-utilization', str(self.gpu_memory_utilization),
                    '--tensor-parallel-size', '1'
                ]
            
            env = os.environ.copy()
            env['CUDA_VISIBLE_DEVICES'] = str(gpu_id)
            env['HF_HOME'] = '/root/.cache/huggingface'
            
            print(f"  Starting instance {i+1} on GPU {gpu_id}, port {port}")
            print(f"    Model: {self.model_name}")
            print(f"    Command: {' '.join(cmd)}")
            
            process = subprocess.Popen(cmd, env=env)
            self.processes.append({
                'process': process,
                'gpu_id': gpu_id,
                'port': port,
                'instance_name': f"{self.model_name.replace('-', '_').replace(':', '_')}_{i+1}"
            })
            
            # Small delay between starts
            time.sleep(2)
        
        print(f"[multi-instance] ✅ Completed launching all {len(self.gpus)} vLLM instances")
        print(f"[multi-instance] Total processes created: {len(self.processes)}")
        print(f"[multi-instance] Returning control to main launch method...")
    
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
        env['HF_HOME'] = '/root/.cache/huggingface'
        
        print(f"    Command: {' '.join(cmd)}")
        
        process = subprocess.Popen(cmd, env=env)
        self.processes.append({
            'process': process,
            'gpu_id': ','.join(gpu_ids),
            'port': self.base_port,
            'instance_name': self.model_name.replace('-', '_').replace(':', '_')
        })
    
    def generate_nginx_config(self):
        """Generate nginx configuration based on launched instances"""
        print("\n[nginx] Generating nginx configuration...")
        if self.strategy == 'multi_instance':
            upstreams = []
            locations = []
            backends = []
            
            for i, proc_info in enumerate(self.processes):
                port = proc_info['port']
                instance_name = proc_info['instance_name']
                
                # Individual instance upstream
                upstreams.append(f"""upstream {instance_name} {{server localhost:{port};}}""")
                
                # Individual instance location
                locations.append(f"""
                    # Route to {instance_name}
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
                
                backends.append(f"server localhost:{port};")
            
            # Load balancer upstream with least_conn for better load balancing
            backend_list = chr(10).join([f"        {backend}" for backend in backends])
            upstreams.append(f"""upstream vllm_backends {{ least_conn; {backend_list} }}""")

            # Load balancing for /v1/ path
            locations.append("""
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
            upstreams = [f"""upstream vllm_backends {{server localhost:{port};}}"""]
            
            locations = ["""
                # Single instance with tensor parallelism
                location /v1/ {{
                    proxy_pass http://vllm_backends;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                    proxy_read_timeout 300s;
                    proxy_connect_timeout 75s;
                }}"""]
                    
        nginx_config = f"""
            events {{worker_connections 1024;}}

            http {{
                # Enable access logs for debugging
                access_log /var/log/nginx/access.log;
                error_log /var/log/nginx/error.log;
                
            {chr(10).join(upstreams)}

                server {{
                    listen {self.nginx_port};
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
        
        # Create nginx directory and write config
        import os
        os.makedirs('/etc/nginx', exist_ok=True)
        nginx_config_path = '/etc/nginx/nginx.conf'
        with open(nginx_config_path, 'w') as f:
            f.write(nginx_config)
        
        print(f"[nginx] Generated nginx configuration at {nginx_config_path}")
        preview = "\n".join(nginx_config.splitlines()[:12])
        print("[nginx] Config preview (first lines):\n" + preview)
        print("Instance summary:")
        for proc_info in self.processes:
            print(f"  - {proc_info['instance_name']}: GPU {proc_info['gpu_id']}, port {proc_info['port']}")
    
    def start_nginx(self):
        """Start nginx with the generated configuration"""
        print("\n[nginx] Starting nginx...")
        try:
            print("[nginx] Testing configuration (nginx -t)...")
            test_result = subprocess.run(['nginx', '-t'], capture_output=True, text=True)
            if test_result.stdout.strip():
                print("[nginx] test stdout:\n" + test_result.stdout.strip())
            if test_result.stderr.strip():
                print("[nginx] test stderr:\n" + test_result.stderr.strip())
            if test_result.returncode != 0:
                print("[nginx] Configuration test failed.")
                sys.exit(1)
            print("[nginx] Configuration test passed.")
            print("[nginx] Launching master process (daemon off)...")
            nginx_process = subprocess.Popen(['nginx', '-g', 'daemon off;'])
            self.processes.append({
                'process': nginx_process,
                'gpu_id': 'N/A',
                'port': self.nginx_port,
                'instance_name': 'nginx'
            })
            print(f"[nginx] Process started (PID {nginx_process.pid}). Waiting for readiness on port {self.nginx_port}...")
            # Readiness check
            deadline = time.time() + 15
            ready = False
            while time.time() < deadline:
                try:
                    with socket.create_connection(("127.0.0.1", self.nginx_port), timeout=0.5):
                        ready = True
                        break
                except OSError:
                    time.sleep(0.5)
            if ready:
                print(f"[nginx] Ready: accepting connections on port {self.nginx_port}")
                # Optional health probe
                try:
                    import urllib.request
                    with urllib.request.urlopen(f"http://127.0.0.1:{self.nginx_port}/health", timeout=2) as r:
                        if r.status == 200:
                            print("[nginx] Health endpoint responded OK.")
                except Exception:
                    print("[nginx] Health endpoint not reachable yet (will continue).")
            else:
                print("[nginx] Warning: nginx not confirmed ready within timeout.")
        except Exception as e:
            print(f"[nginx] Failed to start nginx: {e}")
            sys.exit(1)
    
    
    def launch(self):
        """Main launch method"""
        if not self.gpus:
            print("No GPUs detected!")
            sys.exit(1)
        
        if self.strategy == 'multi_instance':
            print(f"[launcher] Starting multi-instance launch...")
            self.launch_multi_instance()
            print(f"[launcher] Multi-instance launch completed, {len(self.processes)} processes started")
        elif self.strategy == 'tensor_parallel':
            print(f"[launcher] Starting tensor-parallel launch...")
            self.launch_tensor_parallel()
            print(f"[launcher] Tensor-parallel launch completed, {len(self.processes)} processes started")
        else:
            print(f"Unknown strategy: {self.strategy}")
            sys.exit(1)
        
        # Generate nginx config and start nginx immediately
        print(f"\n[launcher] vLLM launch phase complete. Starting nginx load balancer...")
        print(f"[launcher] Process count: {len(self.processes)} (excluding nginx)")
        print(f"[launcher] 🚀 Starting nginx - vLLM instances will become available as they finish loading")
        
        self.generate_nginx_config()
        self.start_nginx()
        
        print(f"[launcher] ✅ nginx started successfully! Load balancer is ready.")
        print(f"[launcher] vLLM instances will handle requests as they become available.")
        
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
        print("[launcher] Press Ctrl+C to shutdown")
        
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