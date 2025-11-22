#!/bin/bash

echo "🔗 Configuring component integrations..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Read outputs from all services
KEYCLOAK_URL=$(grep "KEYCLOAK_URL" ./outputs/keycloak_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "")
OPA_URL=$(grep "OPA_URL" ./outputs/opa_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "")

echo "📋 Integration Summary:"
echo "  - Keycloak: ${KEYCLOAK_URL:-Not available}"
echo "  - OPA: ${OPA_URL:-Not available}"
echo "  - ZTNA Tunnel: $(grep "TUNNEL_URL" ./outputs/ztna_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "Not available")"
echo "  - Wazuh: $(grep "WAZUH_URL" ./outputs/wazuh_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "Not available")"
echo "  - CrowdSec: $(grep "CROWDSEC_API" ./outputs/crowdsec_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "Not available")"
echo "  - Traefik: $(grep "TRAEFIK_URL" ./outputs/traefik_outputs.txt 2>/dev/null | cut -d'=' -f2 || echo "Not available")"

# Create simple integration documentation
cat > ./outputs/integration_guide.md << 'EOF'
# Zero Trust Architecture Integration Guide

## Component Connections

### 1. Keycloak IAM
- **URL**: http://localhost:8080
- **Admin**: admin / [password from keycloak_outputs.txt]
- **Purpose**: Central identity management and authentication

### 2. OPA Policy Engine
- **URL**: http://localhost:8181
- **Health Check**: http://localhost:8181/health
- **Purpose**: Dynamic authorization policies

### 3. ZTNA Tunnel
- **URL**: http://localhost:8081
- **Purpose**: Secure network access demonstration

### 4. Wazuh SIEM
- **URL**: https://localhost:55000
- **Credentials**: admin / admin
- **Purpose**: Security monitoring and alerting

### 5. CrowdSec
- **URL**: http://localhost:8082
- **Purpose**: Real-time threat protection

### 6. Traefik Proxy
- **URL**: http://localhost:8080/dashboard/
- **Purpose**: Policy enforcement and routing

## Next Steps for Integration

1. **Configure Keycloak Clients**:
   - Create clients for OPA, Traefik, and applications
   - Set up users and roles

2. **Define OPA Policies**:
   - Modify policies in ./policies/ directory
   - Test policies via OPA API

3. **Set up Application Routing**:
   - Configure Traefik to use OPA for authorization
   - Set up secure routes through ZTNA tunnel

4. **Monitor Security Events**:
   - Check Wazuh for security alerts
   - Review CrowdSec decisions
EOF

echo "✅ Integration configuration complete"
echo "📖 See ./outputs/integration_guide.md for next steps"
