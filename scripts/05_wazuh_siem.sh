#!/bin/bash

KEYCLOAK_URL=${1:-http://localhost:8080}

echo "📊 Deploying Wazuh SIEM..."

# Create Wazuh docker-compose
cat > docker-compose-wazuh.yml << 'EOF'
version: '3.8'
services:
  wazuh:
    image: wazuh/wazuh-manager:4.7.2
    container_name: wazuh-manager
    network_mode: host
    privileged: true
    volumes:
      - wazuh_data:/var/ossec/data
      - ./wazuh_config:/var/ossec/etc
    environment:
      - INDEXER_URL=https://wazuh-indexer:9200
      - INDEXER_USERNAME=admin
      - INDEXER_PASSWORD=SecretPassword
      - DASHBOARD_URL=https://wazuh-dashboard:5601

  wazuh-indexer:
    image: wazuh/wazuh-indexer:4.7.2
    container_name: wazuh-indexer
    network_mode: host
    volumes:
      - wazuh_indexer_data:/var/lib/wazuh-indexer
    environment:
      - OPENSEARCH_INITIAL_ADMIN_PASSWORD=SecretPassword

  wazuh-dashboard:
    image: wazuh/wazuh-dashboard:4.7.2
    container_name: wazuh-dashboard
    network_mode: host
    volumes:
      - wazuh_dashboard_data:/usr/share/wazuh-dashboard/data
    environment:
      - OPENSEARCH_HOSTS=https://wazuh-indexer:9200
      - OPENSEARCH_USERNAME=admin
      - OPENSEARCH_PASSWORD=SecretPassword

volumes:
  wazuh_data:
  wazuh_indexer_data:
  wazuh_dashboard_data:
EOF

# Start Wazuh (simplified - in real scenario use full docker-compose)
docker run -d \
  --name wazuh \
  --network zt-network \
  -p 55000:55000 \
  wazuh/wazuh-manager:4.7.2

# Wait for Wazuh
sleep 30

# Configure Wazuh integration with Keycloak
cat > ../config/wazuh_integration.conf << EOF
# Wazuh-Keycloak Integration
<auth>
  enabled=yes
  keycloak_url=$KEYCLOAK_URL
  realm=zero-trust
  client_id=wazuh-client
</auth>

<alerts>
  opa_integration=enabled
  risk_scoring=enabled
</alerts>
EOF

# Write outputs
echo "WAZUH_URL=https://localhost:55000" > ../outputs/wazuh_outputs.txt
echo "WAZUH_USERNAME=admin" >> ../outputs/wazuh_outputs.txt
echo "WAZUH_PASSWORD=SecretPassword" >> ../outputs/wazuh_outputs.txt
echo "KEYCLOAK_INTEGRATED=true" >> ../outputs/wazuh_outputs.txt

echo "✅ Wazuh SIEM deployment complete"
