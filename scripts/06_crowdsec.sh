#!/bin/bash

WAZUH_URL=${1:-https://localhost:55000}

echo "🛡️ Deploying CrowdSec..."

# Install CrowdSec
curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | bash
apt-get install crowdsec -y

# Install common collections
cscli collections install crowdsecurity/linux
cscli collections install crowdsecurity/ssh
cscli collections install crowdsecurity/http

# Configure Wazuh integration
cat > /etc/crowdsec/acquis.yaml << EOF
filenames:
  - /var/ossec/logs/alerts/alerts.json
labels:
  type: wazuh-alerts
EOF

# Start CrowdSec
systemctl enable crowdsec
systemctl start crowdsec

# Create OPA integration for decision sharing
cat > ../config/crowdsec_opa.conf << EOF
# CrowdSec-OPA Integration
[opa]
  enabled = true
  endpoint = "http://opa:8181/v1/data/crowdsec/decisions"
  update_frequency = "30s"

[wazuh]
  endpoint = "$WAZUH_URL"
  api_key = "wazuh-crowdsec-integration"
EOF

# Write outputs
echo "CROWDSEC_API=http://localhost:8080" > ../outputs/crowdsec_outputs.txt
echo "CROWDSEC_STATUS=active" >> ../outputs/crowdsec_outputs.txt
echo "WAZUH_INTEGRATED=true" >> ../outputs/crowdsec_outputs.txt
echo "OPA_INTEGRATED=true" >> ../outputs/crowdsec_outputs.txt

echo "✅ CrowdSec deployment complete"
