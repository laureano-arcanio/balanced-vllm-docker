# DevOps Project Rules & Best Practices

## 🎯 Overview

This document establishes DevOps best practices and rules for the Balanced vLLM Docker project to ensure consistent, secure, and maintainable operations.

## 📋 General Principles

### 1. **Infrastructure as Code (IaC)**
- All infrastructure components must be defined as code
- Use version-controlled configuration files
- Document all infrastructure changes
- Test infrastructure changes before production deployment

### 2. **Configuration Management**
- **Environment Variables**: Use `.env` files for local development, never commit secrets
- **Secrets Management**: Use secure secret management systems (Docker secrets, K8s secrets, vault)
- **Configuration Validation**: Validate all configuration before deployment
- **Environment Parity**: Keep development, staging, and production environments as similar as possible

### 3. **Version Control Standards**
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Create meaningful commit messages
- Use feature branches for development
- Require pull request reviews for main branch changes

## 🐳 Container Management Rules

### **Docker Best Practices**

#### Image Building
```bash
# ✅ GOOD: Use specific base image versions
FROM nvidia/cuda:12.4.0-runtime-ubuntu22.04

# ❌ BAD: Using latest tag
FROM nvidia/cuda:latest
```

#### Multi-Stage Builds
- Use multi-stage builds to reduce image size
- Keep build dependencies separate from runtime
- Optimize layer caching for faster builds

#### Security
```dockerfile
# ✅ GOOD: Run as non-root user when possible
RUN useradd -m appuser
USER appuser

# ✅ GOOD: Use specific package versions
RUN apt-get update && apt-get install -y \
    curl=7.81.0-1ubuntu1.4 \
    && rm -rf /var/lib/apt/lists/*
```

#### Environment Variables
```yaml
# ✅ GOOD: Use environment variables for configuration
environment:
  - VLLM_MODEL=${VLLM_MODEL:-facebook/opt-125m}
  - VLLM_GPU_MEMORY_UTILIZATION=${VLLM_GPU_MEMORY_UTILIZATION:-0.80}

# ❌ BAD: Hardcoded values in Dockerfile
ENV VLLM_MODEL=facebook/opt-125m
```

### **Container Runtime Rules**

#### Resource Management
```yaml
# ✅ GOOD: Set resource limits
deploy:
  resources:
    limits:
      memory: 32G
    reservations:
      memory: 16G
      devices:
        - driver: nvidia
          count: all
          capabilities: [gpu]
```

#### Health Checks
```yaml
# ✅ GOOD: Implement comprehensive health checks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 15s
  retries: 5
  start_period: 180s
```

#### Logging
```yaml
# ✅ GOOD: Configure logging drivers
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

## 🚀 Deployment Guidelines

### **Environment Management**

#### Development Environment
```bash
# ✅ GOOD: Use specific environment configurations
VLLM_MODEL=facebook/opt-125m
VLLM_GPU_MEMORY_UTILIZATION=0.7
VLLM_MAX_MODEL_LEN=1024
```

#### Production Environment
```bash
# ✅ GOOD: Production-optimized settings
VLLM_INSTALL_TYPE=gptoss
VLLM_GPU_MEMORY_UTILIZATION=0.95
VLLM_MAX_MODEL_LEN=4096
VLLM_STRATEGY=multi_instance
```

### **Deployment Strategies**

#### Blue-Green Deployment
- Maintain two identical production environments
- Switch traffic between environments for zero-downtime deployments
- Test new versions thoroughly before traffic switch

#### Rolling Updates
- Update instances gradually to maintain availability
- Monitor system health during updates
- Implement automatic rollback on failure

### **Pre-deployment Checklist**
- [ ] Configuration validated
- [ ] Health checks passing
- [ ] Resource limits appropriate
- [ ] Security scans completed
- [ ] Backup procedures verified
- [ ] Rollback plan documented

## 🔒 Security Best Practices

### **Container Security**

#### Image Security
```bash
# ✅ GOOD: Scan images for vulnerabilities
docker scout cves balanced-vllm:latest

# ✅ GOOD: Use distroless or minimal base images where possible
FROM gcr.io/distroless/python3-debian12
```

#### Runtime Security
```yaml
# ✅ GOOD: Use security options
security_opt:
  - no-new-privileges:true
  - seccomp:default

# ✅ GOOD: Run with read-only root filesystem where possible
read_only: true
tmpfs:
  - /tmp
  - /var/run
```

### **Secrets Management**

#### Environment Variables
```bash
# ✅ GOOD: Use secrets management
docker secret create hf_token hf_token.txt
docker service create --secret hf_token myapp

# ❌ BAD: Plain text secrets in docker-compose.yml
environment:
  - HF_TOKEN=hf_1234567890abcdef
```

#### File Permissions
```bash
# ✅ GOOD: Restrict secret file permissions
chmod 600 .env
chown root:root .env
```

### **Network Security**
```yaml
# ✅ GOOD: Use custom networks
networks:
  vllm-network:
    driver: bridge
    internal: false
```

## 📊 Monitoring & Observability

### **Health Monitoring**

#### Application Health
```python
# ✅ GOOD: Comprehensive health checks
def health_check():
    checks = {
        'gpu_available': check_gpu_status(),
        'model_loaded': check_model_status(),
        'memory_usage': check_memory_usage(),
        'nginx_status': check_nginx_status()
    }
    return all(checks.values())
```

#### System Metrics
```yaml
# ✅ GOOD: Expose metrics for monitoring
labels:
  - "prometheus.io/scrape=true"
  - "prometheus.io/port=9090"
  - "prometheus.io/path=/metrics"
```

### **Logging Standards**

#### Structured Logging
```python
# ✅ GOOD: Use structured logging
import logging
import json

logger = logging.getLogger(__name__)

def log_gpu_status(gpu_info):
    logger.info(json.dumps({
        'event': 'gpu_detected',
        'gpu_count': len(gpu_info),
        'total_memory_gb': sum(gpu['memory_total'] for gpu in gpu_info),
        'timestamp': datetime.utcnow().isoformat()
    }))
```

#### Log Aggregation
```yaml
# ✅ GOOD: Configure log aggregation
logging:
  driver: "fluentd"
  options:
    fluentd-address: "localhost:24224"
    tag: "vllm.{{.ContainerName}}"
```

## ⚙️ Configuration Management

### **Environment-Specific Configurations**

#### Development (.env.dev)
```bash
# Development optimized
VLLM_MODEL=facebook/opt-125m
VLLM_GPU_COUNT=1
VLLM_GPU_MEMORY_UTILIZATION=0.7
VLLM_MAX_MODEL_LEN=1024
DEBUG=true
```

#### Staging (.env.staging)
```bash
# Production-like with safety margins
VLLM_MODEL=microsoft/DialoGPT-medium
VLLM_GPU_COUNT=2
VLLM_GPU_MEMORY_UTILIZATION=0.8
VLLM_MAX_MODEL_LEN=2048
DEBUG=false
```

#### Production (.env.prod)
```bash
# Production optimized
VLLM_INSTALL_TYPE=gptoss
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
VLLM_STRATEGY=multi_instance
VLLM_GPU_MEMORY_UTILIZATION=0.95
VLLM_MAX_MODEL_LEN=4096
DEBUG=false
```

### **Configuration Validation**
```python
# ✅ GOOD: Validate configuration on startup
def validate_config():
    required_vars = ['VLLM_MODEL', 'VLLM_STRATEGY']
    missing = [var for var in required_vars if not os.getenv(var)]
    if missing:
        raise ValueError(f"Missing required environment variables: {missing}")
    
    gpu_mem = float(os.getenv('VLLM_GPU_MEMORY_UTILIZATION', '0.8'))
    if not 0.1 <= gpu_mem <= 0.95:
        raise ValueError("GPU memory utilization must be between 0.1 and 0.95")
```

## 🔄 CI/CD Best Practices

### **Continuous Integration**

#### Build Pipeline
```yaml
# ✅ GOOD: Multi-stage build pipeline
stages:
  - lint
  - security-scan
  - build
  - test
  - integration-test
  - deploy
```

#### Testing Strategy
```bash
# ✅ GOOD: Comprehensive testing
# Unit tests
pytest tests/unit/

# Integration tests
pytest tests/integration/

# Container tests
docker run --rm -v $(pwd):/app -w /app python:3.12 pytest

# GPU tests (if available)
nvidia-docker run --rm -v $(pwd):/app myimage pytest tests/gpu/
```

### **Continuous Deployment**

#### Automated Deployments
- Deploy automatically to development environment
- Require approval for staging deployments
- Require multiple approvals for production deployments

#### Deployment Gates
- All tests must pass
- Security scans must complete successfully
- Performance benchmarks must meet thresholds
- Manual approval required for production

## 🎛️ Operations Rules

### **Capacity Planning**
```bash
# ✅ GOOD: Monitor resource usage patterns
# Track GPU utilization
nvidia-smi --query-gpu=utilization.gpu --format=csv --loop=60

# Monitor memory usage
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Track request patterns
curl -s http://localhost/metrics | grep request_duration
```

### **Incident Response**

#### Runbooks
- Document common failure scenarios
- Provide step-by-step recovery procedures
- Include escalation procedures
- Test runbooks regularly

#### Alerting Thresholds
```yaml
# ✅ GOOD: Define clear alerting thresholds
alerts:
  gpu_memory_usage:
    warning: 85%
    critical: 95%
  response_time:
    warning: 5s
    critical: 10s
  error_rate:
    warning: 1%
    critical: 5%
```

### **Maintenance Windows**
- Schedule regular maintenance windows
- Notify users in advance
- Perform updates during low-traffic periods
- Test rollback procedures

## 📝 Documentation Standards

### **Required Documentation**
- [ ] README.md with quick start guide
- [ ] CLAUDE.md with technical overview (this file)
- [ ] PROJECT_RULES.md with best practices (this file)
- [ ] API documentation
- [ ] Deployment guides
- [ ] Troubleshooting guides
- [ ] Architecture diagrams

### **Change Documentation**
- Document all configuration changes
- Maintain change logs
- Update architecture diagrams
- Review documentation regularly

## 🛠️ Development Workflow

### **Feature Development**
1. Create feature branch from main
2. Implement changes with tests
3. Update documentation
4. Create pull request
5. Conduct code review
6. Merge after approval

### **Hotfix Process**
1. Create hotfix branch from main
2. Implement minimal fix
3. Test thoroughly
4. Deploy to production immediately
5. Merge back to main and develop

### **Code Review Guidelines**
- Review for security vulnerabilities
- Check resource usage patterns
- Verify configuration management
- Ensure proper error handling
- Validate documentation updates

## ⚡ Performance Guidelines

### **GPU Optimization**
```bash
# ✅ GOOD: Monitor GPU utilization
nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total --format=csv --loop=30

# ✅ GOOD: Optimize memory usage
VLLM_GPU_MEMORY_UTILIZATION=0.95  # Production
VLLM_GPU_MEMORY_UTILIZATION=0.8   # Development
```

### **Network Optimization**
```nginx
# ✅ GOOD: Optimize nginx for ML workloads
proxy_read_timeout 300s;
proxy_connect_timeout 75s;
proxy_buffering off;
```

### **Model Optimization**
- Use model quantization when appropriate
- Implement model caching strategies
- Monitor model loading times
- Track inference performance metrics

## 🚨 Emergency Procedures

### **System Recovery**
1. Identify failing components
2. Check system logs
3. Verify GPU status
4. Restart services if necessary
5. Escalate if unresolved within SLA

### **Rollback Procedures**
```bash
# ✅ GOOD: Quick rollback capability
docker-compose down
git checkout previous-stable-tag
docker-compose up -d
```

### **Data Recovery**
- Maintain regular backups of model cache
- Document recovery procedures
- Test recovery procedures regularly
- Maintain offsite backups for critical data

---

**Last Updated**: 2025-08-10  
**Review Cycle**: Monthly  
**Next Review**: 2025-09-10