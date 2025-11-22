#!/bin/bash

echo "🌐 Setting up ZTNA Tunnel..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Simple nginx demo tunnel
docker run -d \
  --name ztna-tunnel \
  --network zt-network \
  -p 8081:80 \
  nginx:alpine

# Wait for tunnel to start
sleep 5

# Write outputs
echo "TUNNEL_URL=http://localhost:8081" > ./outputs/ztna_outputs.txt
echo "TUNNEL_STATUS=active" >> ./outputs/ztna_outputs.txt
echo "TUNNEL_TYPE=nginx-demo" >> ./outputs/ztna_outputs.txt

echo "✅ ZTNA tunnel setup complete - Demo tunnel: http://localhost:8081"
