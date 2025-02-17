#!/bin/bash

# Check if a domain name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN=$1
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
WEB_ROOT="/var/www/$DOMAIN"

# Stop Nginx to free port 80 for Certbot
echo "Stopping Nginx..."
sudo systemctl stop nginx

# Issue SSL certificate
echo "Issuing SSL certificate for $DOMAIN..."
sudo certbot certonly --standalone -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN

# Restart Nginx after cert issuance
echo "Starting Nginx..."
sudo systemctl start nginx

# Create web root directory
echo "Creating web root directory at $WEB_ROOT..."
sudo mkdir -p "$WEB_ROOT"
sudo chown -R www-data:www-data "$WEB_ROOT"

# Create Nginx configuration
echo "Creating Nginx configuration for $DOMAIN..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    root $WEB_ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

# Enable the site
echo "Enabling $DOMAIN..."
sudo ln -s "$NGINX_CONF" "$NGINX_ENABLED"

# Test Nginx configuration
echo "Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx to apply changes
echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "✅ Site $DOMAIN has been successfully added and secured with SSL!"
