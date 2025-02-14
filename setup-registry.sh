#!/bin/bash
set -e

# ---------------------------------------------
# Docker Installation (if not already installed)
# ---------------------------------------------
if ! command -v docker &> /dev/null; then
  echo "Docker not found. Installing Docker..."
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl
  
  # Add Docker’s official GPG key:
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  
  # Add the repository to Apt sources:
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  
  # Install Docker packages:
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "Docker is already installed."
fi

# ---------------------------------------------
# Install apache2-utils for htpasswd if not present
# ---------------------------------------------
if ! command -v htpasswd &> /dev/null; then
  echo "Installing apache2-utils for htpasswd..."
  sudo apt-get install -y apache2-utils
fi

# ---------------------------------------------
# Prompt for input values
# ---------------------------------------------
read -p "Enter your Cloudflare subdomain (e.g., testregistery.example.com): " DOMAIN
read -p "Enter the registry username: " USERNAME
read -sp "Enter the registry password: " PASSWORD
echo
echo "Using domain: $DOMAIN, username: $USERNAME"

# ---------------------------------------------
# Define directories for registry data, auth, and certs
# ---------------------------------------------
DATA_DIR="/opt/registry/data"
AUTH_DIR="/opt/registry/auth"
CERTS_DIR="/opt/registry/certs"

echo "Creating directories..."
sudo mkdir -p "$DATA_DIR" "$AUTH_DIR" "$CERTS_DIR"

# ---------------------------------------------
# Generate a self-signed certificate
# ---------------------------------------------
echo "Generating self-signed certificate for $DOMAIN..."
sudo openssl req -newkey rsa:4096 -nodes -sha256 \
  -keyout "$CERTS_DIR/domain.key" \
  -x509 -days 365 \
  -out "$CERTS_DIR/domain.crt" \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# ---------------------------------------------
# Create htpasswd file for authentication
# ---------------------------------------------
echo "Creating htpasswd file..."
# The -B option uses bcrypt. The -c option creates a new file.
echo "$PASSWORD" | sudo htpasswd -Bci "$AUTH_DIR/htpasswd" "$USERNAME"

# ---------------------------------------------
# Run the Docker registry container
# ---------------------------------------------
echo "Starting Docker registry container..."
sudo docker run -d -p 5000:5000 --restart=always --name registry \
  -v "$DATA_DIR":/var/lib/registry \
  -v "$CERTS_DIR":/certs \
  -v "$AUTH_DIR":/auth \
  -e REGISTRY_HTTP_ADDR=0.0.0.0:5000 \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  -e REGISTRY_AUTH=htpasswd \
  -e REGISTRY_AUTH_HTPASSWD_REALM="Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  registry:2

echo "Docker private registry has been successfully set up!"
echo "Access it via https://$DOMAIN (Cloudflare proxy on port 443)"
