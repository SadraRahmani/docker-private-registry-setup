#!/bin/bash

# Check if a domain name and port number are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <domain> <port>"
    exit 1
fi

DOMAIN=$1
PORT=$2
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

# Check if renewal is needed
if sudo certbot certificates | grep -q "VALID: .*([1-9] days\|[12][0-9] days\|0 days)"; then
    echo "🔔 Certificate renewal required. Stopping Nginx..."
    sudo systemctl stop nginx

    echo "🔄 Renewing certificates..."
    sudo certbot renew --quiet

    echo "🚀 Restarting Nginx..."
    sudo systemctl start nginx
else
    echo "✅ Certificates are valid. No renewal needed."
fi

# Create Nginx configuration
echo "📝 Creating Nginx reverse proxy configuration for $DOMAIN (forwarding to port $PORT)..."
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

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

# Enable the site
echo "✅ Enabling $DOMAIN..."
sudo ln -sf "$NGINX_CONF" "$NGINX_ENABLED"

# Test Nginx configuration
echo "🔍 Testing Nginx configuration..."
sudo nginx -t

# Restart Nginx
echo "🚀 Restarting Nginx..."
sudo systemctl restart nginx

echo "🎉 $DOMAIN is now live and reverse proxied to port $PORT with SSL!"
