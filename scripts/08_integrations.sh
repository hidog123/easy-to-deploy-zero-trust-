#!/bin/bash

echo "🔗 Setting up component integrations..."

# Read outputs from all services
KEYCLOAK_URL=$(grep "KEYCLOAK_URL" ../outputs/keycloak_outputs.txt | cut -d'=' -f2)
OPA_URL=$(grep "OPA_URL" ../outputs/opa_outputs.txt | cut -d'=' -f2)
WAZUH_URL=$(grep "WAZUH_URL" ../outputs/wazuh_outputs.txt | cut -d'=' -f2)

# Configure OPA to use Keycloak for token verification
curl -X PUT "$OPA_URL/v1/policies/keycloak" \
  -H "Content-Type: text/plain" \
  --data-binary @../policies/keycloak_integration.rego

# Configure Wazuh to send alerts to OPA for risk scoring
curl -X POST "$WAZUH_URL/webhook/opa" \
  -H "Content-Type: application/json" \
  -d "{\"opa_endpoint\": \"$OPA_URL/v1/data/risk/scoring\"}"

# Configure Traefik to use OPA for authorization
curl -X POST "$TRAEFIK_URL/api/providers/opa" \
  -H "Content-Type: application/json" \
  -d "{\"address\": \"$OPA_URL/v1/data/traefik/authz\"}"

echo "✅ Component integrations complete"
