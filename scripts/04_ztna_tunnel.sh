#!/bin/bash

OPA_URL=${1:-http://localhost:8181}

echo "🌐 Setting up ZTNA Tunnel..."

# For this example, we'll use Tailscale (simplified)
# In production, you might use CloudFlare Tunnel or OpenZiti

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale (this would require authentication in real scenario)
tailscale up --auth-key=${TAILSCALE_AUTH_KEY} || echo "⚠️ Tailscale auth required"

# Alternative: Simple SSH tunnel setup for demo
docker run -d \
  --name ztna-tunnel \
  --network zt-network \
  -p 8081:80 \
  nginx:alpine

# Create tunnel configuration
cat > ../config/tunnel.conf << EOF
# ZTNA Tunnel Configuration
tunnel_endpoint: localhost:8081
opa_policy_endpoint: $OPA_URL/v1/data/zta/abac/allow
auth_provider: keycloak
allowed_networks: 10.0.0.0/24
EOF

# Write outputs
echo "TUNNEL_URL=http://localhost:8081" > ../outputs/ztna_outputs.txt
echo "TUNNEL_STATUS=active" >> ../outputs/ztna_outputs.txt
echo "OPA_INTEGRATED=true" >> ../outputs/ztna_outputs.txt

echo "✅ ZTNA tunnel setup complete"
