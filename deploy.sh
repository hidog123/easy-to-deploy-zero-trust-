#!/bin/bash

set -e

# Load global configuration
source ./config/global.env

echo "🚀 Starting Zero Trust Architecture Deployment"
echo "============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to log outputs
log_output() {
    local service=$1
    local key=$2
    local value=$3
    echo "$key=$value" >> "./outputs/${service}_outputs.txt"
}

# Function to get output from previous deployments
get_output() {
    local service=$1
    local key=$2
    grep "$key" "./outputs/${service}_outputs.txt" | cut -d'=' -f2
}

# 1. Prerequisites
echo -e "${YELLOW}📋 Step 1: Installing prerequisites...${NC}"
./scripts/01_prerequisites.sh
source ./outputs/prerequisites_outputs.txt

# 2. Keycloak IAM Setup
echo -e "${YELLOW}🔐 Step 2: Deploying Keycloak IAM...${NC}"
./scripts/02_keycloak_setup.sh
KEYCLOAK_URL=$(get_output "keycloak" "KEYCLOAK_URL")
KEYCLOAK_CLIENT_SECRET=$(get_output "keycloak" "CLIENT_SECRET")
echo -e "${GREEN}✅ Keycloak deployed at: $KEYCLOAK_URL${NC}"

# 3. OPA Policy Engine
echo -e "${YELLOW}⚖️ Step 3: Deploying OPA Policy Engine...${NC}"
./scripts/03_opa_policies.sh "$KEYCLOAK_URL" "$KEYCLOAK_CLIENT_SECRET"
OPA_URL=$(get_output "opa" "OPA_URL")
echo -e "${GREEN}✅ OPA deployed at: $OPA_URL${NC}"

# 4. ZTNA Tunnel Setup
echo -e "${YELLOW}🌐 Step 4: Setting up ZTNA Tunnel...${NC}"
./scripts/04_ztna_tunnel.sh "$OPA_URL"
TUNNEL_URL=$(get_output "ztna" "TUNNEL_URL")
echo -e "${GREEN}✅ ZTNA Tunnel established: $TUNNEL_URL${NC}"

# 5. Wazuh SIEM
echo -e "${YELLOW}📊 Step 5: Deploying Wazuh SIEM...${NC}"
./scripts/05_wazuh_siem.sh "$KEYCLOAK_URL"
WAZUH_URL=$(get_output "wazuh" "WAZUH_URL")
echo -e "${GREEN}✅ Wazuh SIEM deployed at: $WAZUH_URL${NC}"

# 6. CrowdSec Protection
echo -e "${YELLOW}🛡️ Step 6: Deploying CrowdSec...${NC}"
./scripts/06_crowdsec.sh "$WAZUH_URL"
CROWDSEC_API=$(get_output "crowdsec" "CROWDSEC_API")
echo -e "${GREEN}✅ CrowdSec deployed${NC}"

# 7. Traefik Proxy
echo -e "${YELLOW}🔀 Step 7: Deploying Traefik Proxy...${NC}"
./scripts/07_traefik_proxy.sh "$OPA_URL" "$KEYCLOAK_URL"
TRAEFIK_URL=$(get_output "traefik" "TRAEFIK_URL")
echo -e "${GREEN}✅ Traefik deployed at: $TRAEFIK_URL${NC}"

# 8. Integration Setup
echo -e "${YELLOW}🔗 Step 8: Configuring integrations...${NC}"
./scripts/08_integrations.sh

echo -e "${GREEN}🎉 Zero Trust Architecture deployment completed!${NC}"
echo "============================================="
echo "Access URLs:"
echo "Keycloak IAM: $KEYCLOAK_URL"
echo "OPA Policy: $OPA_URL"
echo "ZTNA Tunnel: $TUNNEL_URL"
echo "Wazuh SIEM: $WAZUH_URL"
echo "Traefik Proxy: $TRAEFIK_URL"
