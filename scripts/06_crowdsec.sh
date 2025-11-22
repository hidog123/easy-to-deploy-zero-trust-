#!/bin/bash

echo "🛡️ Deploying CrowdSec..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Simple CrowdSec demo
docker run -d \
  --name crowdsec \
  --network zt-network \
  -p 8082:8080 \
  crowdsecurity/crowdsec:latest

# Write outputs
echo "CROWDSEC_API=http://localhost:8082" > ./outputs/crowdsec_outputs.txt
echo "STATUS=active" >> ./outputs/crowdsec_outputs.txt

echo "✅ CrowdSec deployment complete - Demo API: http://localhost:8082"
