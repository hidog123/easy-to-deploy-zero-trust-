#!/bin/bash

OPA_URL=${1:-http://localhost:8181}
KEYCLOAK_URL=${2:-http://localhost:8080}

echo "🔀 Deploying Traefik Proxy..."

# Create Traefik configuration
mkdir -p ../config/traefik

cat > ../config/traefik/traefik.yml << EOF
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
  level: DEBUG

accessLog: {}
EOF

# Create dynamic configuration with OPA integration
cat > ../config/traefik/dynamic.yml << EOF
http:
  middlewares:
    opa-auth:
      forwardAuth:
        address: "$OPA_URL/v1/data/traefik/authz"
        trustForwardHeader: true
        authResponseHeaders:
          - "X-User"
          - "X-Roles"
    
    keycloak-auth:
      forwardAuth:
        address: "$KEYCLOAK_URL/realms/zero-trust/protocol/openid-connect/auth"
        trustForwardHeader: true

  routers:
    api-router:
      rule: "Host(\`api.zerotrust.local\`)"
      middlewares:
        - opa-auth
        - keycloak-auth
      service: api-service
      tls: true

    dashboard-router:
      rule: "Host(\`dashboard.zerotrust.local\`)"
      middlewares:
        - opa-auth
      service: dashboard-service
      tls: true

  services:
    api-service:
      loadBalancer:
        servers:
          - url: "http://api:3000"

    dashboard-service:
      loadBalancer:
        servers:
          - url: "http://dashboard:3001"
EOF

# Deploy Traefik
docker run -d \
  --name traefik \
  --network zt-network \
  -p 80:80 \
  -p 443:443 \
  -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v $(pwd)/../config/traefik/traefik.yml:/etc/traefik/traefik.yml \
  -v $(pwd)/../config/traefik/dynamic.yml:/etc/traefik/dynamic/dynamic.yml \
  traefik:latest

# Write outputs
echo "TRAEFIK_URL=http://localhost:8080" > ../outputs/traefik_outputs.txt
echo "TRAEFIK_DASHBOARD=http://localhost:8080/dashboard" >> ../outputs/traefik_outputs.txt
echo "OPA_INTEGRATION=active" >> ../outputs/traefik_outputs.txt
echo "KEYCLOAK_INTEGRATION=active" >> ../outputs/traefik_outputs.txt

echo "✅ Traefik deployment complete"
