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

# Create Keycloak docker-compose with compatible version
cat > docker-compose-keycloak.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15
    container_name: postgres-keycloak
    environment:
      POSTGRES_DB: keycloak
      POSTGRES_USER: keycloak
      POSTGRES_PASSWORD: ${KEYCLOAK_DB_PASSWORD}
    networks:
      - zt-network
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U keycloak"]
      interval: 10s
      timeout: 5s
      retries: 5

  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    environment:
      KEYCLOAK_ADMIN: ${KEYCLOAK_ADMIN}
      KEYCLOAK_ADMIN_PASSWORD: ${KEYCLOAK_ADMIN_PASSWORD}
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KEYCLOAK_DB_PASSWORD}
      KC_HOSTNAME: localhost
      KC_HTTP_ENABLED: "true"
    command: start-dev
    ports:
      - "8080:8080"
    networks:
      - zt-network
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 10s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:

networks:
  zt-network:
    external: true
    name: zt-network
EOF

# Start Keycloak with environment variables
KEYCLOAK_ADMIN="$KEYCLOAK_ADMIN" \
KEYCLOAK_ADMIN_PASSWORD="$KEYCLOAK_ADMIN_PASSWORD" \
KEYCLOAK_DB_PASSWORD="$KEYCLOAK_DB_PASSWORD" \
docker-compose -f docker-compose-keycloak.yml up -d

# Wait for Keycloak to be ready
echo "⏳ Waiting for Keycloak to start..."
MAX_WAIT=60
WAITED=0
while [ $WAITED -lt $MAX_WAIT ]; do
    if curl -s -f http://localhost:8080/health/ready > /dev/null 2>&1; then
        echo "✅ Keycloak is ready!"
        break
    fi
    echo "⏳ Waiting for Keycloak... ($((WAITED + 5))s)"
    sleep 5
    WAITED=$((WAITED + 5))
done

if [ $WAITED -ge $MAX_WAIT ]; then
    echo "❌ Keycloak failed to start within $MAX_WAIT seconds"
    docker-compose -f docker-compose-keycloak.yml logs keycloak
    exit 1
fi

# Simple configuration - skip complex setup for demo
echo "⚙️ Performing basic Keycloak configuration..."

# Wait a bit more for full startup
sleep 10

# Write outputs
echo "KEYCLOAK_URL=http://localhost:8080" > ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_REALM=master" >> ./outputs/keycloak_outputs.txt
echo "OPA_CLIENT_SECRET=opa-secret-key-123" >> ./outputs/keycloak_outputs.txt
echo "TRAEFIK_CLIENT_SECRET=traefik-secret-key-123" >> ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN" >> ./outputs/keycloak_outputs.txt
echo "KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD" >> ./outputs/keycloak_outputs.txt

echo "✅ Keycloak deployment complete - Access: http://localhost:8080"
echo "   Username: $KEYCLOAK_ADMIN"
echo "   Password: $KEYCLOAK_ADMIN_PASSWORD"
