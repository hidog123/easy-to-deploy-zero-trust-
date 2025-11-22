#!/bin/bash

echo "🔐 Setting up Keycloak IAM..."

# Generate Keycloak configuration
source ./config/keycloak.env

# Start Keycloak container
docker run -d \
  --name keycloak \
  -e KEYCLOAK_ADMIN=$KEYCLOAK_ADMIN \
  -e KEYCLOAK_ADMIN_PASSWORD=$KEYCLOAK_ADMIN_PASSWORD \
  -p 8080:8080 \
  quay.io/keycloak/keycloak:latest start-dev

# Wait for Keycloak to be ready
until curl -f -s http://localhost:8080/auth/realms/master > /dev/null; do
    sleep 5
done

# Configure Keycloak realm, clients, users
# ... Keycloak configuration commands ...

# Extract outputs for other services
KEYCLOAK_URL="http://localhost:8080"
CLIENT_SECRET=$(keycloak_script_to_get_client_secret)

# Write outputs for other scripts
echo "KEYCLOAK_URL=$KEYCLOAK_URL" > ../outputs/keycloak_outputs.txt
echo "CLIENT_SECRET=$CLIENT_SECRET" >> ../outputs/keycloak_outputs.txt
echo "REALM=zero-trust" >> ../outputs/keycloak_outputs.txt

echo "✅ Keycloak setup complete"
