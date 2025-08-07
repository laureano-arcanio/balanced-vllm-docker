#!/bin/bash

# Generate docker-compose.yml based on instances.config

CONFIG_FILE="instances.config"
OUTPUT_FILE="docker-compose.yml"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found"
    exit 1
fi

echo "Generating $OUTPUT_FILE from $CONFIG_FILE..."

# Start writing docker-compose.yml
cat > "$OUTPUT_FILE" << 'EOF'
version: '3.8'

services:
EOF

# Process each instance in the config
INSTANCE_COUNT=0
NGINX_UPSTREAMS=""
NGINX_LOCATIONS=""

while IFS=':' read -r NAME PORT MODEL DEVICE MAX_MODEL_LEN TENSOR_PARALLEL; do
    # Skip comments and empty lines
    if [[ "$NAME" =~ ^#.*$ ]] || [[ -z "$NAME" ]]; then
        continue
    fi
    
    INSTANCE_COUNT=$((INSTANCE_COUNT + 1))
    
    echo "  # vLLM Instance: $NAME" >> "$OUTPUT_FILE"
    echo "  $NAME:" >> "$OUTPUT_FILE"
    echo "    build: ." >> "$OUTPUT_FILE"
    echo "    container_name: vllm_$NAME" >> "$OUTPUT_FILE"
    echo "    command: /app/start_instance.sh $NAME" >> "$OUTPUT_FILE"
    echo "    ports:" >> "$OUTPUT_FILE"
    echo "      - \"$PORT:$PORT\"" >> "$OUTPUT_FILE"
    echo "    volumes:" >> "$OUTPUT_FILE"
    echo "      - ./models:/root/.cache/huggingface" >> "$OUTPUT_FILE"
    echo "    environment:" >> "$OUTPUT_FILE"
    
    if [ "$DEVICE" != "auto" ] && [ "$DEVICE" != "cpu" ]; then
        echo "      - CUDA_VISIBLE_DEVICES=$DEVICE" >> "$OUTPUT_FILE"
    fi
    
    echo "    deploy:" >> "$OUTPUT_FILE"
    echo "      resources:" >> "$OUTPUT_FILE"
    
    if [ "$DEVICE" != "cpu" ]; then
        echo "        reservations:" >> "$OUTPUT_FILE"
        echo "          devices:" >> "$OUTPUT_FILE"
        echo "            - driver: nvidia" >> "$OUTPUT_FILE"
        echo "              count: 1" >> "$OUTPUT_FILE"
        echo "              capabilities: [gpu]" >> "$OUTPUT_FILE"
    fi
    
    echo "    restart: unless-stopped" >> "$OUTPUT_FILE"
    echo "    healthcheck:" >> "$OUTPUT_FILE"
    echo "      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:$PORT/health\"]" >> "$OUTPUT_FILE"
    echo "      interval: 30s" >> "$OUTPUT_FILE"
    echo "      timeout: 10s" >> "$OUTPUT_FILE"
    echo "      retries: 3" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    
    # Add to nginx upstreams and locations
    NGINX_UPSTREAMS="${NGINX_UPSTREAMS}upstream ${NAME} {\n    server ${NAME}:${PORT};\n}\n\n"
    
    NGINX_LOCATIONS="${NGINX_LOCATIONS}    # Route to ${NAME}\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}    location /v1/${NAME}/ {\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        rewrite ^/v1/${NAME}/(.*) /v1/\$1 break;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_pass http://${NAME};\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_set_header Host \$host;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_set_header X-Real-IP \$remote_addr;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_set_header X-Forwarded-Proto \$scheme;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_read_timeout 300s;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}        proxy_connect_timeout 75s;\n"
    NGINX_LOCATIONS="${NGINX_LOCATIONS}    }\n\n"
    
done < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$')

# Add nginx service
cat >> "$OUTPUT_FILE" << 'EOF'
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: vllm_reverse_proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
EOF

# Add dependencies for all instances
while IFS=':' read -r NAME PORT MODEL DEVICE MAX_MODEL_LEN TENSOR_PARALLEL; do
    if [[ "$NAME" =~ ^#.*$ ]] || [[ -z "$NAME" ]]; then
        continue
    fi
    echo "      - $NAME" >> "$OUTPUT_FILE"
done < <(grep -v '^#' "$CONFIG_FILE" | grep -v '^$')

cat >> "$OUTPUT_FILE" << 'EOF'
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  models:
EOF

# Generate nginx.conf
echo "Generating nginx.conf..."
cat > nginx.conf << 'EOF'
# Auto-generated nginx configuration

EOF

echo -e "$NGINX_UPSTREAMS" >> nginx.conf

cat >> nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

EOF

echo -e "$NGINX_LOCATIONS" >> nginx.conf

# Get first instance for default route
FIRST_INSTANCE=$(grep -v '^#' "$CONFIG_FILE" | grep -v '^$' | head -n1 | cut -d':' -f1)

cat >> nginx.conf << EOF
    # Default route to first instance ($FIRST_INSTANCE)
    location /v1/ {
        proxy_pass http://$FIRST_INSTANCE;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }

    # Root route
    location / {
        proxy_pass http://$FIRST_INSTANCE;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

echo "Generated $OUTPUT_FILE with $INSTANCE_COUNT instances"
echo "Generated nginx.conf with routing for all instances"
echo "Run 'docker-compose up --build' to start all services"
