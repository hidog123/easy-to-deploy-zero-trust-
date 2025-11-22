#!/bin/bash

echo "📋 Installing prerequisites..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Script directory: $SCRIPT_DIR"
echo "Project root: $PROJECT_ROOT"

cd "$PROJECT_ROOT"

# Create necessary directories
mkdir -p ./outputs ./logs ./config ./policies

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Not running as root, some installations may fail"
fi

# Update system (with Cloud Shell warning suppression)
export DEBIAN_FRONTEND=noninteractive
mkdir -p ~/.cloudshell
touch ~/.cloudshell/no-apt-get-warning

echo "Updating package lists..."
apt-get update > /dev/null 2>&1

# Install basic dependencies
echo "Installing basic dependencies..."
apt-get install -y curl wget git jq openssl > /dev/null 2>&1

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh > /dev/null 2>&1
    rm get-docker.sh
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
    echo "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Create Docker network for Zero Trust
echo "Creating Docker network..."
docker network create zt-network > /dev/null 2>&1 || true

# Generate SSL certificates in the correct location
echo "Generating SSL certificates..."
cd "$PROJECT_ROOT/config"
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout zt-key.pem -out zt-cert.pem \
    -subj "/C=FR/ST=Paris/L=Paris/O=ZeroTrust/CN=zerotrust.local" 2>/dev/null

cd "$PROJECT_ROOT"

# Write outputs
echo "DOCKER_NETWORK=zt-network" > ./outputs/prerequisites_outputs.txt
echo "SSL_CERT=./config/zt-cert.pem" >> ./outputs/prerequisites_outputs.txt
echo "SSL_KEY=./config/zt-key.pem" >> ./outputs/prerequisites_outputs.txt
echo "PROJECT_ROOT=$PROJECT_ROOT" >> ./outputs/prerequisites_outputs.txt

echo "✅ Prerequisites installed successfully"
