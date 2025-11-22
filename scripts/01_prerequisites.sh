#!/bin/bash

echo "📋 Installing prerequisites..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run as root or with sudo"
    exit 1
fi

# Update system
apt-get update
apt-get install -y curl wget git docker.io docker-compose jq openssl

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Create Docker network for Zero Trust
docker network create zt-network || true

# Create necessary directories
mkdir -p ../outputs ../logs ../policies

# Generate SSL certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout ../config/zt-key.pem -out ../config/zt-cert.pem \
    -subj "/C=FR/ST=Paris/L=Paris/O=ZeroTrust/CN=zerotrust.local"

# Write outputs
echo "DOCKER_NETWORK=zt-network" > ../outputs/prerequisites_outputs.txt
echo "SSL_CERT=../config/zt-cert.pem" >> ../outputs/prerequisites_outputs.txt
echo "SSL_KEY=../config/zt-key.pem" >> ../outputs/prerequisites_outputs.txt

echo "✅ Prerequisites installed successfully"
