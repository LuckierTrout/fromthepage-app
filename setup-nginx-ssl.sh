#!/bin/bash

# Nginx + SSL Setup Script for luckiertrout.com
# Run this AFTER your initial deployment is working

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🔒 Setting up Nginx + SSL for luckiertrout.com"
echo "=============================================="

# Check if FromThePage is running
if ! docker-compose ps | grep -q "Up"; then
    print_error "FromThePage containers are not running!"
    print_error "Please run './deploy-to-digitalocean.sh' first"
    exit 1
fi

print_status "FromThePage is running, proceeding with Nginx setup..."

# Install Nginx and Certbot
print_status "Installing Nginx and Certbot..."
apt update
apt install -y nginx certbot python3-certbot-nginx

# Stop default Nginx site
print_status "Configuring Nginx..."
rm -f /etc/nginx/sites-enabled/default

# Copy our Nginx configuration
cp nginx-luckiertrout.conf /etc/nginx/sites-available/luckiertrout
ln -sf /etc/nginx/sites-available/luckiertrout /etc/nginx/sites-enabled/

# Test Nginx configuration
if nginx -t; then
    print_status "Nginx configuration is valid"
else
    print_error "Nginx configuration failed!"
    exit 1
fi

# Start Nginx
systemctl enable nginx
systemctl restart nginx

# Wait a moment for Nginx to start
sleep 5

# Check if domain resolves to this server
DOMAIN_IP=$(dig +short luckiertrout.com)
SERVER_IP=$(curl -s ifconfig.me)

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    print_warning "Domain DNS may not be configured correctly"
    print_warning "Domain IP: $DOMAIN_IP"
    print_warning "Server IP: $SERVER_IP"
    print_warning "Make sure your DNS A record points to $SERVER_IP"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get SSL certificate
print_status "Getting SSL certificate from Let's Encrypt..."
if certbot --nginx -d luckiertrout.com -d www.luckiertrout.com --non-interactive --agree-tos --email admin@luckiertrout.com; then
    print_status "✅ SSL certificate obtained successfully!"
else
    print_error "Failed to get SSL certificate"
    print_error "This might be due to:"
    print_error "1. DNS not pointing to this server yet"
    print_error "2. Firewall blocking port 80/443"
    print_error "3. Domain not accessible from the internet"
    exit 1
fi

# Set up automatic certificate renewal
print_status "Setting up automatic certificate renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

print_status "✅ Nginx + SSL setup completed successfully!"
echo ""
echo "🌐 Your site is now available at:"
echo "   https://luckiertrout.com"
echo "   https://www.luckiertrout.com"
echo ""
echo "🔒 SSL certificate will auto-renew every 12 hours"
echo ""
print_status "Testing the setup..."
echo "Checking HTTP redirect..."
curl -I http://luckiertrout.com | head -n 5
echo ""
echo "Checking HTTPS..."
curl -I https://luckiertrout.com | head -n 5 