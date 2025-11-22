#!/bin/bash

echo "⚖️ Deploying OPA Policy Engine..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Create policies directory
mkdir -p ./policies

# Simple ABAC policy
cat > ./policies/abac_policies.rego << 'EOF'
package zta.abac

default allow = false

allow {
    # Identity verification
    input.identity.authenticated == true
    input.identity.roles[_] == "user"
    
    # Basic context checks
    input.context.geolocation == "FR"
    input.context.hour >= 8
    input.context.hour <= 18
    
    # Device compliance
    input.device.compliant == true
}

# Risk scoring policy
package zta.risk

risk_score := 0.1 {
    input.context.geolocation == "FR"
} else := 0.8

risk_score := 0.1 {
    input.device.compliant == true
} else := 0.9
EOF

# Deploy OPA
docker run -d \
  --name opa \
  --network zt-network \
  -p 8181:8181 \
  -v "$(pwd)/policies:/policies" \
  openpolicyagent/opa:latest \
  run --server --log-level debug /policies/

# Wait for OPA
echo "⏳ Waiting for OPA to start..."
sleep 10

until curl -s http://localhost:8181/health > /dev/null; do
    sleep 2
done

# Load policies
curl -X PUT http://localhost:8181/v1/policies/abac \
  --data-binary @./policies/abac_policies.rego

# Write outputs
echo "OPA_URL=http://localhost:8181" > ./outputs/opa_outputs.txt
echo "POLICIES_LOADED=abac,risk" >> ./outputs/opa_outputs.txt
echo "STATUS=active" >> ./outputs/opa_outputs.txt

echo "✅ OPA deployment complete - Access: http://localhost:8181"
