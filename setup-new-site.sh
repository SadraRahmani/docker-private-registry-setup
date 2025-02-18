#!/bin/bash

# Check if domain and port are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <domain> <port>"
    exit 1
fi

DOMAIN=$1
PORT=$2
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"
WEB_ROOT="/var/www/$DOMAIN"

# Create web root directory for Let's Encrypt challenge
echo "Creating web root directory at $WEB_ROOT..."
sudo mkdir -p "$WEB_ROOT"
sudo chown -R www-data:www-data "$WEB_ROOT"

# Create Nginx configuration
echo "Creating Nginx configuration for $DOMAIN..."
sudo tee "$NGINX_CONF" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
        allow all;
    }

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable the site
echo "Enabling $DOMAIN..."
sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED"

# Issue SSL certificate using webroot
echo "Issuing SSL certificate for $DOMAIN..."
sudo certbot certonly --webroot -w /var/www/html -d "$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN

echo "✅ Site $DOMAIN is now secured with SSL and reverse proxying to port $PORT!"
