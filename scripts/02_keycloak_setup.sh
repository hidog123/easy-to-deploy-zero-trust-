#!/bin/bash

echo "🔐 Deploying Keycloak IAM..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Set default values if config file doesn't exist
if [ -f "./config/keycloak.env" ]; then
    source "./config/keycloak.env"
else
    echo "⚠️ Keycloak config not found, using defaults"
    KEYCLOAK_ADMIN=admin
    KEYCLOAK_ADMIN_PASSWORD=admin123
    KEYCLOAK_DB_PASSWORD=keycloakdb123
fi

echo "Starting Keycloak with PostgreSQL..."

# First, start PostgreSQL
echo "Starting PostgreSQL..."
docker run -d \
  --name postgres-keycloak \
  --network zt-network \
  -e POSTGRES_DB=keycloak \
  -e POSTGRES_USER=keycloak \
  -e POSTGRES_PASSWORD=$KEYCLOAK_DB_PASSWORD \
  -p 5432:5432 \
  postgres:15

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to start..."
sleep 10

# Start Keycloak
echo "Starting Keycloak..."
docker run -d \
  --name keycloak \
  --network zt-network \
  -e KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN \
  -e KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD \
  -e KC_DB=postgres \
  -e KC_DB_URL=jdbc:postgresql://postgres-keycloak:5432/keycloak \
  -e KC_DB_USERNAME=keycloak \
  -e KC_DB_PASSWORD=$KEYCLOAK_DB_PASSWORD \
  -e KC_HOSTNAME=localhost \
  -e KC_HTTP_ENABLED=true \
  -p 8080:8080 \
  quay.io/keycloak/keycloak:latest \
  start-dev

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to start..."
MAX_WAIT=90
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s -f http://localhost:8080 > /dev/null 2>&1; then
        echo "✅ Keycloak is ready!"
        break
    fi
    echo "⏳ Waiting for Keycloak... ($((WAITED + 5))s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ Keycloak failed to start within $MAX_WAIT seconds"
    echo "Checking Keycloak logs..."
    docker logs keycloak
    echo "⏳ Continuing deployment anyway..."
fi

# Write outputs
echo "KEYCLOAK_URL=http://localhost:8080" > ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_REALM=master" >> ./outputs/keycloak_outputs.txt
echo "OPA_CLIENT_SECRET=opa-secret-key-123" >> ./outputs/keycloak_outputs.txt
echo "TRAEFIK_CLIENT_SECRET=traefik-secret-key-123" >> ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN" >> ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD" >> ./outputs/keycloak_outputs.txt
echo "POSTGRES_URL=postgres-keycloak:5432" >> ./outputs/keycloak_outputs.txt

echo "✅ Keycloak deployment complete - Access: http://localhost:8080"
echo "   Username: $KEYCLOAK_ADMIN"
echo "   Password: $KEYCLOAK_ADMIN_PASSWORD"
echo "   Default realm: master"
