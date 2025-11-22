#!/bin/bash

echo "🔐 Deploying Keycloak IAM..."

source ../config/keycloak.env

# Create Keycloak docker-compose
cat > docker-compose-keycloak.yml << EOF
version: '3.8'
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: $KEYCLOAK_ADMIN
      KEYCLOAK_ADMIN_PASSWORD: $KEYCLOAK_ADMIN_PASSWORD
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: $KEYCLOAK_DB_PASSWORD
    command: start-dev
    ports:
      - "8080:8080"
    networks:
      - zt-network
    depends_on:
      - postgres

  postgres:
    image: postgres:15
    container_name: postgres-keycloak
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: $KEYCLOAK_DB_PASSWORD
    networks:
      - zt-network
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:

networks:
  zt-network:
    external: true
EOF

# Start Keycloak
docker-compose -f docker-compose-keycloak.yml up -d

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to start..."
until curl -s -f http://localhost:8080 > /dev/null; do
    sleep 10
done

# Configure Keycloak realm and client
echo "⚙️ Configuring Keycloak realm and clients..."

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST \
  http://localhost:8080/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=$KEYCLOAK_ADMIN&password=$KEYCLOAK_ADMIN_PASSWORD&grant_type=password&client_id=admin-cli" | jq -r '.access_token')

# Create Zero Trust realm
curl -s -X POST \
  http://localhost:8080/admin/realms \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "realm": "zero-trust",
    "enabled": true,
    "displayName": "Zero Trust Realm"
  }'

# Create OPA client
curl -s -X POST \
  http://localhost:8080/admin/realms/zero-trust/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "opa-client",
    "enabled": true,
    "publicClient": false,
    "secret": "opa-secret-key",
    "protocol": "openid-connect"
  }'

# Create Traefik client
curl -s -X POST \
  http://localhost:8080/admin/realms/zero-trust/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "clientId": "traefik-client",
    "enabled": true,
    "publicClient": false,
    "secret": "traefik-secret-key",
    "protocol": "openid-connect"
  }'

# Write outputs
echo "KEYCLOAK_URL=http://localhost:8080" > ../outputs/keycloak_outputs.txt
echo "KEYCLOAK_REALM=zero-trust" >> ../outputs/keycloak_outputs.txt
echo "OPA_CLIENT_SECRET=opa-secret-key" >> ../outputs/keycloak_outputs.txt
echo "TRAEFIK_CLIENT_SECRET=traefik-secret-key" >> ../outputs/keycloak_outputs.txt
echo "ADMIN_TOKEN=$ADMIN_TOKEN" >> ../outputs/keycloak_outputs.txt

echo "✅ Keycloak deployment complete"
