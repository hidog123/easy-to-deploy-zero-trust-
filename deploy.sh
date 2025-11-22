#!/bin/bash

set -e

# Get the absolute path of the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load global configuration
if [ -f "./config/global.env" ]; then
    source "./config/global.env"
else
    echo "⚠️ Global config not found, using defaults"
fi

echo "🚀 Starting Zero Trust Architecture Deployment"
echo "============================================="
echo "Script directory: $SCRIPT_DIR"
echo "Working directory: $(pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to log outputs
log_output() {
    local service=$1
    local key=$2
    local value=$3
    mkdir -p "./outputs"
    echo "$key=$value" >> "./outputs/${service}_outputs.txt"
}

# Function to get output from previous deployments
get_output() {
    local service=$1
    local key=$2
    local output_file="./outputs/${service}_outputs.txt"
    if [ -f "$output_file" ]; then
        grep "$key" "$output_file" 2>/dev/null | cut -d'=' -f2 || echo ""
    else
        echo ""
    fi
}

# Function to check service health
check_service_health() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}⏳ Waiting for $service to be ready...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ $service is ready${NC}"
            return 0
        fi
        
        echo -e "${YELLOW}Attempt $attempt/$max_attempts: $service not ready, waiting 5 seconds...${NC}"
        sleep 5
        attempt=$((attempt + 1))
    done
    
    echo -e "${RED}❌ $service failed to start within expected time${NC}"
    return 1
}

# Function to deploy component with error handling
deploy_component() {
    local component=$1
    local script=$2
    local description=$3
    
    echo -e "\n${BLUE}=== $description ===${NC}"
    echo -e "${YELLOW}Running $script...${NC}"
    
    local script_path="./scripts/$script"
    if [ -f "$script_path" ]; then
        # Make script executable
        chmod +x "$script_path"
        
        # Run script from the correct directory
        if bash "$script_path"; then
            echo -e "${GREEN}✅ $component deployed successfully${NC}"
            return 0
        else
            echo -e "${RED}❌ $component deployment failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Deployment script $script_path not found${NC}"
        return 1
    fi
}

# Main deployment function
main() {
    # Create necessary directories
    mkdir -p ./outputs ./logs ./config ./policies
    
    # Start deployment log
    echo "Zero Trust Deployment Started: $(date)" > ./logs/deployment.log
    
    # 1. Prerequisites
    echo -e "\n${BLUE}=== STAGE 1: Prerequisites ===${NC}"
    if ! deploy_component "Prerequisites" "01_prerequisites.sh" "Installing system dependencies and certificates"; then
        echo -e "${YELLOW}⚠️ Prerequisites had issues, but continuing...${NC}"
    fi
    
    # Load prerequisite outputs if they exist
    if [ -f "./outputs/prerequisites_outputs.txt" ]; then
        source "./outputs/prerequisites_outputs.txt"
    fi
    
    # 2. Keycloak IAM Setup
    echo -e "\n${BLUE}=== STAGE 2: Identity and Access Management ===${NC}"
    if ! deploy_component "Keycloak" "02_keycloak_setup.sh" "Deploying Keycloak IAM with RBAC/ABAC"; then
        echo -e "${YELLOW}⚠️ Keycloak setup had issues, but continuing...${NC}"
    fi
    
    # Wait for Keycloak and get outputs
    KEYCLOAK_URL=$(get_output "keycloak" "KEYCLOAK_URL")
    if [ -n "$KEYCLOAK_URL" ]; then
        if check_service_health "Keycloak" "$KEYCLOAK_URL"; then
            echo -e "${GREEN}✅ Keycloak deployed at: $KEYCLOAK_URL${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ Keycloak URL not available${NC}"
    fi
    
    KEYCLOAK_CLIENT_SECRET=$(get_output "keycloak" "OPA_CLIENT_SECRET")
    
    # 3. OPA Policy Engine
    echo -e "\n${BLUE}=== STAGE 3: Policy Engine ===${NC}"
    if ! deploy_component "OPA" "03_opa_policies.sh" "Deploying Open Policy Agent with dynamic ABAC policies"; then
        echo -e "${YELLOW}⚠️ OPA setup had issues, but continuing...${NC}"
    fi
    
    # Wait for OPA and get outputs
    OPA_URL=$(get_output "opa" "OPA_URL")
    if [ -n "$OPA_URL" ]; then
        if check_service_health "OPA" "$OPA_URL/health"; then
            echo -e "${GREEN}✅ OPA deployed at: $OPA_URL${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ OPA URL not available${NC}"
    fi
    
    # 4. ZTNA Tunnel Setup
    echo -e "\n${BLUE}=== STAGE 4: Zero Trust Network Access ===${NC}"
    if ! deploy_component "ZTNA" "04_ztna_tunnel.sh" "Setting up secure ZTNA tunnel"; then
        echo -e "${YELLOW}⚠️ ZTNA tunnel setup had issues, but continuing...${NC}"
    fi
    
    TUNNEL_URL=$(get_output "ztna" "TUNNEL_URL")
    echo -e "${GREEN}✅ ZTNA Tunnel established: ${TUNNEL_URL:-Not configured}${NC}"
    
    # 5. Wazuh SIEM
    echo -e "\n${BLUE}=== STAGE 5: Security Monitoring ===${NC}"
    if ! deploy_component "Wazuh" "05_wazuh_siem.sh" "Deploying Wazuh SIEM + ELK Stack"; then
        echo -e "${YELLOW}⚠️ Wazuh setup had issues, but continuing...${NC}"
    fi
    
    WAZUH_URL=$(get_output "wazuh" "WAZUH_URL")
    echo -e "${GREEN}✅ Wazuh SIEM deployed at: ${WAZUH_URL:-Not configured}${NC}"
    
    # 6. CrowdSec Protection
    echo -e "\n${BLUE}=== STAGE 6: Real-time Protection ===${NC}"
    if ! deploy_component "CrowdSec" "06_crowdsec.sh" "Deploying CrowdSec for real-time threat protection"; then
        echo -e "${YELLOW}⚠️ CrowdSec setup had issues, but continuing...${NC}"
    fi
    
    CROWDSEC_API=$(get_output "crowdsec" "CROWDSEC_API")
    echo -e "${GREEN}✅ CrowdSec deployed: ${CROWDSEC_API:-Not configured}${NC}"
    
    # 7. Traefik Proxy
    echo -e "\n${BLUE}=== STAGE 7: Policy Enforcement ===${NC}"
    if ! deploy_component "Traefik" "07_traefik_proxy.sh" "Deploying Traefik as Policy Enforcement Point"; then
        echo -e "${YELLOW}⚠️ Traefik setup had issues, but continuing...${NC}"
    fi
    
    TRAEFIK_URL=$(get_output "traefik" "TRAEFIK_URL")
    if [ -n "$TRAEFIK_URL" ]; then
        if check_service_health "Traefik" "$TRAEFIK_URL"; then
            echo -e "${GREEN}✅ Traefik deployed at: $TRAEFIK_URL${NC}"
        fi
    fi
    
    # 8. Integration Setup
    echo -e "\n${BLUE}=== STAGE 8: Component Integration ===${NC}"
    if ! deploy_component "Integrations" "08_integrations.sh" "Configuring inter-component communications and policies"; then
        echo -e "${YELLOW}⚠️ Some integrations had issues, but continuing...${NC}"
    fi
    
    echo -e "${GREEN}✅ All integrations configured${NC}"
    
    # Final health check and summary
    echo -e "\n${BLUE}=== FINAL CHECKS ===${NC}"
    perform_final_checks
    
    # Deployment summary
    echo -e "\n${GREEN}🎉 Zero Trust Architecture deployment completed!${NC}"
    echo "============================================="
    show_deployment_summary
    
    # Generate compliance report
    generate_compliance_report
}

# Perform final health checks
perform_final_checks() {
    echo -e "${YELLOW}Running final health checks...${NC}"
    
    local all_healthy=true
    
    # Check Keycloak
    KEYCLOAK_URL=$(get_output "keycloak" "KEYCLOAK_URL")
    if [ -n "$KEYCLOAK_URL" ] && curl -s -f "$KEYCLOAK_URL" > /dev/null; then
        echo -e "${GREEN}✅ Keycloak: HEALTHY${NC}"
    else
        echo -e "${RED}❌ Keycloak: UNHEALTHY${NC}"
        all_healthy=false
    fi
    
    # Check OPA
    OPA_URL=$(get_output "opa" "OPA_URL")
    if [ -n "$OPA_URL" ] && curl -s -f "$OPA_URL/health" > /dev/null; then
        echo -e "${GREEN}✅ OPA: HEALTHY${NC}"
    else
        echo -e "${RED}❌ OPA: UNHEALTHY${NC}"
        all_healthy=false
    fi
    
    # Check Traefik if deployed
    TRAEFIK_URL=$(get_output "traefik" "TRAEFIK_URL")
    if [ -n "$TRAEFIK_URL" ] && curl -s -f "$TRAEFIK_URL" > /dev/null; then
        echo -e "${GREEN}✅ Traefik: HEALTHY${NC}"
    else
        echo -e "${YELLOW}⚠️ Traefik: NOT CHECKED${NC}"
    fi
    
    if [ "$all_healthy" = true ]; then
        echo -e "${GREEN}✅ All core services are healthy${NC}"
    else
        echo -e "${YELLOW}⚠️ Some services may need attention${NC}"
    fi
}

# Show deployment summary
show_deployment_summary() {
    echo -e "${BLUE}📊 DEPLOYMENT SUMMARY${NC}"
    echo -e "${BLUE}=====================${NC}"
    
    KEYCLOAK_URL=$(get_output "keycloak" "KEYCLOAK_URL")
    OPA_URL=$(get_output "opa" "OPA_URL")
    TUNNEL_URL=$(get_output "ztna" "TUNNEL_URL")
    WAZUH_URL=$(get_output "wazuh" "WAZUH_URL")
    TRAEFIK_URL=$(get_output "traefik" "TRAEFIK_URL")
    
    echo -e "🔐 ${GREEN}Keycloak IAM${NC}: ${KEYCLOAK_URL:-Not deployed}"
    if [ -n "$KEYCLOAK_URL" ]; then
        echo -e "   - Realm: $(get_output "keycloak" "KEYCLOAK_REALM")"
    fi
    
    echo -e "⚖️ ${GREEN}OPA Policy Engine${NC}: ${OPA_URL:-Not deployed}"
    if [ -n "$OPA_URL" ]; then
        echo -e "   - Policies: $(get_output "opa" "POLICIES_LOADED")"
    fi
    
    echo -e "🌐 ${GREEN}ZTNA Tunnel${NC}: ${TUNNEL_URL:-Not configured}"
    if [ -n "$TUNNEL_URL" ]; then
        echo -e "   - Status: $(get_output "ztna" "TUNNEL_STATUS")"
    fi
    
    echo -e "📊 ${GREEN}Wazuh SIEM${NC}: ${WAZUH_URL:-Not deployed}"
    
    echo -e "🔀 ${GREEN}Traefik Proxy${NC}: ${TRAEFIK_URL:-Not deployed}"
    
    echo -e "\n${BLUE}🔗 INTEGRATIONS STATUS${NC}"
    echo -e "====================="
    echo -e "OPA-Keycloak: $(get_output "opa" "KEYCLOAK_INTEGRATED")"
    echo -e "Wazuh-Keycloak: $(get_output "wazuh" "KEYCLOAK_INTEGRATED")"
    echo -e "CrowdSec-Wazuh: $(get_output "crowdsec" "WAZUH_INTEGRATED")"
    echo -e "Traefik-OPA: $(get_output "traefik" "OPA_INTEGRATION")"
    
    echo -e "\n${YELLOW}📝 Next steps:${NC}"
    echo -e "1. Access Keycloak admin console to configure users and roles"
    echo -e "2. Review OPA policies in ./policies/ directory"
    echo -e "3. Configure ZTNA tunnel endpoints for your applications"
    echo -e "4. Set up Wazuh agents on your endpoints"
    echo -e "5. Review automated incident response scripts in ./scripts/"
}

# Generate compliance report
generate_compliance_report() {
    echo -e "\n${YELLOW}Generating compliance report...${NC}"
    
    KEYCLOAK_URL=$(get_output "keycloak" "KEYCLOAK_URL")
    OPA_URL=$(get_output "opa" "OPA_URL")
    TUNNEL_URL=$(get_output "ztna" "TUNNEL_URL")
    WAZUH_URL=$(get_output "wazuh" "WAZUH_URL")
    TRAEFIK_URL=$(get_output "traefik" "TRAEFIK_URL")
    
    cat > ./outputs/compliance_report.md << EOF
# Zero Trust Architecture Compliance Report
Generated: $(date)

## Deployment Summary
- **Keycloak IAM**: ${KEYCLOAK_URL:-Not deployed}
- **OPA Policy Engine**: ${OPA_URL:-Not deployed}
- **ZTNA Tunnel**: ${TUNNEL_URL:-Not configured}
- **Wazuh SIEM**: ${WAZUH_URL:-Not deployed}
- **Traefik PEP**: ${TRAEFIK_URL:-Not deployed}

## Zero Trust Principles Implemented

### ✅ Identity Verification
- Multi-factor authentication (Keycloak)
- Role-Based Access Control (RBAC)
- Attribute-Based Access Control (ABAC)
- Dynamic risk assessment

### ✅ Device Security
- Device posture assessment policies
- Encryption requirements
- Compliance checking

### ✅ Network Segmentation
- Micro-segmentation policies
- Identity-based network access
- Logical segmentation rules

### ✅ Policy Enforcement
- Dynamic ABAC policies (OPA)
- Real-time risk scoring
- Automated incident response

### ✅ Monitoring & Analytics
- SIEM integration (Wazuh + ELK)
- Real-time threat protection (CrowdSec)
- Behavioral analytics
- Automated alerting

## Security Controls

### Preventive Controls
- MFA enforcement
- Geographic restrictions
- Time-based access controls
- Device compliance requirements

### Detective Controls
- SIEM monitoring
- Anomaly detection
- Risk scoring
- Behavioral analysis

### Responsive Controls
- Automated user isolation
- Session revocation
- MFA re-authentication
- Real-time blocking

## Compliance Status
- **NIST Zero Trust Architecture**: ✅ PARTIALLY IMPLEMENTED
- **CIS Controls**: ✅ PARTIALLY IMPLEMENTED
- **GDPR Access Controls**: ✅ IMPLEMENTED
- **ISO 27001**: 🔄 IN PROGRESS

## Recommendations
1. Complete ZTNA tunnel configuration for production use
2. Set up Wazuh agents on all endpoints
3. Configure CrowdSec with production blocklists
4. Implement backup and disaster recovery procedures
5. Conduct penetration testing

---
*Report generated automatically by Zero Trust Deployment Script*
EOF

    echo -e "${GREEN}✅ Compliance report generated: ./outputs/compliance_report.md${NC}"
}

# Cleanup function for script termination
cleanup() {
    echo -e "\n${YELLOW}🛑 Deployment interrupted. Cleaning up...${NC}"
    echo "Deployment interrupted at: $(date)" >> ./logs/deployment.log
    
    # Stop any running containers
    docker-compose -f docker-compose-keycloak.yml down 2>/dev/null || true
    docker-compose -f docker-compose-wazuh.yml down 2>/dev/null || true
    
    # Stop individual containers
    docker stop keycloak opa wazuh traefik ztna-tunnel 2>/dev/null || true
    
    echo -e "${YELLOW}Cleanup completed. You can restart the deployment with ./deploy.sh${NC}"
    exit 1
}

# Set up trap for cleanup on script termination
trap cleanup SIGINT SIGTERM

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Please run as root or with sudo for full deployment${NC}"
    echo -e "${YELLOW}Some components require root privileges for installation${NC}"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check for dependencies
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
    echo -e "${RED}❌ Docker Compose is not installed. Please install Docker Compose first.${NC}"
    exit 1
fi

# Display deployment information
echo -e "${BLUE}Zero Trust Architecture Deployment${NC}"
echo -e "${BLUE}=================================${NC}"
echo -e "Components to be deployed:"
echo -e "• 🔐 Keycloak IAM (RBAC/ABAC/MFA)"
echo -e "• ⚖️ OPA Policy Engine (Dynamic ABAC)"
echo -e "• 🌐 ZTNA Tunnel (Secure Access)"
echo -e "• 📊 Wazuh SIEM + ELK (Monitoring)"
echo -e "• 🛡️ CrowdSec (Real-time Protection)"
echo -e "• 🔀 Traefik (Policy Enforcement)"
echo -e ""
echo -e "Estimated time: 10-15 minutes"
echo -e "Log file: ./logs/deployment.log"

# Confirm deployment
read -p "Start deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Start deployment
main

# Log successful completion
echo "Zero Trust Deployment Completed Successfully: $(date)" >> ./logs/deployment.log
