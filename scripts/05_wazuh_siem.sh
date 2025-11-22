#!/bin/bash

echo "📊 Deploying Wazuh SIEM..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Simple Wazuh deployment
docker run -d \
  --name wazuh \
  --network zt-network \
  -p 55000:55000 \
  wazuh/wazuh-manager:4.7.2

# Write outputs (Wazuh takes time to start, so we'll just note it's deployed)
echo "WAZUH_URL=https://localhost:55000" > ./outputs/wazuh_outputs.txt
echo "WAZUH_USERNAME=admin" >> ./outputs/wazuh_outputs.txt
echo "WAZUH_PASSWORD=admin" >> ./outputs/wazuh_outputs.txt
echo "STATUS=deploying" >> ./outputs/wazuh_outputs.txt

echo "✅ Wazuh SIEM deployment started - Note: Wazuh may take several minutes to fully start"
echo "   Access: https://localhost:55000 (username: admin, password: admin)"
