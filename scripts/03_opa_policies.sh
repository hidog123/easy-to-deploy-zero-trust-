#!/bin/bash

KEYCLOAK_URL=${1:-http://localhost:8080}
CLIENT_SECRET=${2:-opa-secret-key}

echo "⚖️ Deploying OPA Policy Engine..."

# Create OPA policies directory
mkdir -p ../policies/opa

# Main ABAC policy
cat > ../policies/abac_policies.rego << 'EOF'
package zta.abac

import future.keywords.in

default allow = false

# Main authorization decision
allow {
    # Identity verification
    input.identity.authenticated
    input.identity.roles[_] == required_role
    
    # Context verification
    geo_compliant
    time_compliant
    device_compliant
    
    # Risk assessment
    input.risk.score < risk_threshold
}

# Role-based requirements
required_role = "employee" {
    input.resource.type == "internal-app"
}

required_role = "admin" {
    input.resource.sensitivity == "high"
}

# Geographic compliance
geo_compliant {
    input.context.geolocation in allowed_countries
}

allowed_countries = {"FR", "DE", "BE", "US"}

# Time-based restrictions
time_compliant {
    input.context.hour >= 8
    input.context.hour <= 18
}

# Device compliance
device_compliant {
    input.device.encrypted == true
    input.device.compliant == true
    input.device.antivirus_enabled == true
}

# Risk threshold
risk_threshold = 0.7
EOF

# Risk-based policies
cat > ../policies/risk_policies.rego << 'EOF'
package zta.risk

# Calculate risk score
risk_score = score {
    score := (geo_risk + device_risk + behavior_risk + time_risk) / 4
}

geo_risk = 0.1 {
    input.context.geolocation in low_risk_countries
} else = 0.8

low_risk_countries = {"FR", "DE", "BE"}

device_risk = 0.1 {
    input.device.compliant
} else = 0.9

behavior_risk = 0.1 {
    input.behavior.login_anomaly == false
} else = 0.8

time_risk = 0.1 {
    input.context.hour >= 8
    input.context.hour <= 18
} else = 0.6

# Automatic responses based on risk
automatic_response = "allow" {
    risk_score < 0.3
}

automatic_response = "mfa" {
    risk_score >= 0.3
    risk_score < 0.7
}

automatic_response = "block" {
    risk_score >= 0.7
}

automatic_response = "isolate" {
    risk_score >= 0.9
}
EOF

# Deploy OPA
docker run -d \
  --name opa \
  --network zt-network \
  -p 8181:8181 \
  -v $(pwd)/../policies/:/policies \
  openpolicyagent/opa:latest \
  run --server --log-level debug /policies/

# Wait for OPA
until curl -s http://localhost:8181/health > /dev/null; do
    sleep 5
done

# Load policies into OPA
curl -X PUT http://localhost:8181/v1/policies/abac \
  --data-binary @../policies/abac_policies.rego

curl -X PUT http://localhost:8181/v1/policies/risk \
  --data-binary @../policies/risk_policies.rego

# Write outputs
echo "OPA_URL=http://localhost:8181" > ../outputs/opa_outputs.txt
echo "POLICIES_LOADED=abac,risk" >> ../outputs/opa_outputs.txt

echo "✅ OPA deployment complete"
