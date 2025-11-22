#!/bin/bash

echo "🔀 Deploying Traefik Proxy..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Create Traefik config directory
mkdir -p ./config/traefik

# Simple Traefik config
cat > ./config/traefik/traefik.yml << 'EOF'
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

log:
  level: INFO
EOF

# Deploy Traefik
docker run -d \
  --name traefik \
  --network zt-network \
  -p 80:80 \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v "$(pwd)/config/traefik/traefik.yml:/etc/traefik/traefik.yml" \
  traefik:latest

# Write outputs
echo "TRAEFIK_URL=http://localhost:8080" > ./outputs/traefik_outputs.txt
echo "TRAEFIK_DASHBOARD=http://localhost:8080/dashboard/" >> ./outputs/traefik_outputs.txt
echo "STATUS=active" >> ./outputs/traefik_outputs.txt

echo "✅ Traefik deployment complete - Dashboard: http://localhost:8080/dashboard/"
