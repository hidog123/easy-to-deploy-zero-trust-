#!/bin/bash

echo "🔗 Configuring component integrations..."

# Read all service outputs
KEYCLOAK_URL=$(grep "KEYCLOAK_URL" ../outputs/keycloak_outputs.txt | cut -d'=' -f2)
OPA_URL=$(grep "OPA_URL" ../outputs/opa_outputs.txt | cut -d'=' -f2)
WAZUH_URL=$(grep "WAZUH_URL" ../outputs/wazuh_outputs.txt | cut -d'=' -f2)
TRAEFIK_URL=$(grep "TRAEFIK_URL" ../outputs/traefik_outputs.txt | cut -d'=' -f2)

echo "🔄 Setting up OPA-Keycloak integration..."

# Create OPA policy for Keycloak token verification
cat > ../policies/keycloak_integration.rego << EOF
package system.authz

import future.keywords.in

# Keycloak token verification
keycloak_verify = result {
    response := http.send({
        "method": "GET",
        "url": "$KEYCLOAK_URL/realms/zero-trust/protocol/openid-connect/userinfo",
        "headers": {
            "Authorization": input.attributes.request.http.headers.authorization
        }
    })
    result := response.body
}

# Main authorization logic
default allow = false

allow {
    token := keycloak_verify
    token.active
    token.roles in {"admin", "user"}
    input.attributes.request.http.method == "GET"
}
EOF

# Load Keycloak integration policy into OPA
curl -X PUT "$OPA_URL/v1/policies/keycloak" \
  -H "Content-Type: text/plain" \
  --data-binary @../policies/keycloak_integration.rego

echo "🔄 Setting up Wazuh-OPA risk scoring..."

# Create Wazuh-OPA integration script
cat > ../config/wazuh_opa_integration.sh << 'EOF'
#!/bin/bash
# Wazuh-OPA Risk Scoring Integration

ALERT_JSON="$1"
OPA_ENDPOINT="http://opa:8181/v1/data/wazuh/risk_scoring"

# Send alert to OPA for risk scoring
RISK_SCORE=$(curl -s -X POST "$OPA_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d "$ALERT_JSON" | jq -r '.result.risk_score')

# Take action based on risk score
if [ "$RISK_SCORE" -gt "80" ]; then
    echo "🚨 High risk alert - Triggering isolation"
    # Trigger isolation script
    /opt/zero-trust/scripts/isolate_device.sh "$ALERT_JSON"
elif [ "$RISK_SCORE" -gt "60" ]; then
    echo "⚠️ Medium risk alert - Requiring MFA"
    # Trigger MFA requirement
    /opt/zero-trust/scripts/require_mfa.sh "$ALERT_JSON"
fi
EOF

chmod +x ../config/wazuh_opa_integration.sh

echo "🔄 Configuring Traefik-OPA authorization..."

# Create Traefik OPA policy
cat > ../policies/traefik_authz.rego << 'EOF'
package traefik.authz

import future.keywords.in

default allow = false

allow {
    # Extract JWT token
    token := parsed_token
    token.valid
    
    # Check roles
    token.payload.roles[_] == required_role
    
    # Check context
    input.context.geolocation in allowed_countries
    input.context.time.hour >= 8
    input.context.time.hour <= 18
}

parsed_token := jwt.decode(input.attributes.request.http.headers.authorization)[1] {
    startswith(input.attributes.request.http.headers.authorization, "Bearer ")
}

required_role = "admin" {
    input.attributes.request.http.headers["x-required-role"] == "admin"
} else = "user"

allowed_countries = {"FR", "DE", "BE", "US"}
EOF

# Load Traefik policy into OPA
curl -X PUT "$OPA_URL/v1/policies/traefik" \
  -H "Content-Type: text/plain" \
  --data-binary @../policies/traefik_authz.rego

echo "🔄 Creating automated incident response scripts..."

# Create isolation script
cat > ../scripts/isolate_device.sh << 'EOF'
#!/bin/bash
# Automated Device Isolation Script

ALERT_DATA="$1"
DEVICE_ID=$(echo "$ALERT_DATA" | jq -r '.device.id')
USER_ID=$(echo "$ALERT_DATA" | jq -r '.user.id')

echo "🚨 Isolating device $DEVICE_ID for user $USER_ID"

# Revoke Keycloak sessions
curl -X DELETE "$KEYCLOAK_URL/admin/realms/zero-trust/users/$USER_ID/sessions"

# Block in CrowdSec
cscli decisions add --ip "$DEVICE_IP" --duration 24h --type ban --reason "zero-trust-isolation"

# Log action
echo "$(date): Device $DEVICE_ID isolated due to high risk alert" >> ../logs/incident_response.log
EOF

chmod +x ../scripts/isolate_device.sh

# Create MFA requirement script
cat > ../scripts/require_mfa.sh << 'EOF'
#!/bin/bash
# Require MFA for user

ALERT_DATA="$1"
USER_ID=$(echo "$ALERT_DATA" | jq -r '.user.id')

echo "🔒 Requiring MFA for user $USER_ID"

# Update user in Keycloak to require MFA
curl -X PUT \
  "$KEYCLOAK_URL/admin/realms/zero-trust/users/$USER_ID" \
  -H "Content-Type: application/json" \
  -d '{
    "requiredActions": ["CONFIGURE_TOTP"]
  }'

echo "$(date): MFA required for user $USER_ID" >> ../logs/mfa_actions.log
EOF

chmod +x ../scripts/require_mfa.sh

echo "✅ All integrations configured successfully"
