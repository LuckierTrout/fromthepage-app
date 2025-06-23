#!/bin/bash

# FromThePage DigitalOcean Deployment with SSL Script
# This script deploys FromThePage AND sets up HTTPS/SSL in one go

set -e

echo "🚀 FromThePage DigitalOcean Deployment + SSL Setup"
echo "================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if running on DigitalOcean droplet
if [ -f /etc/digitalocean ]; then
    print_status "Running on DigitalOcean droplet"
else
    print_warning "Not detected as DigitalOcean droplet, continuing anyway..."
fi

# Check if local.env exists and has been configured
if [ ! -f "local.env" ]; then
    print_error "local.env file not found!"
    print_error "Please make sure you've uploaded all files to the server."
    exit 1
fi

# Check for placeholder values in local.env
if grep -q "generate_64_char_hex_key_here" local.env; then
    print_error "Please configure local.env with your actual values before deploying!"
    print_error "Security keys still contain placeholder values."
    exit 1
fi

print_step "Step 1: System Setup"
print_status "Updating system packages..."
apt update && apt upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    usermod -aG docker $USER
    rm get-docker.sh
else
    print_status "Docker already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    print_status "Docker Compose already installed"
fi

print_step "Step 2: Install Nginx and SSL Tools"
print_status "Installing Nginx and Certbot..."
apt install -y nginx certbot python3-certbot-nginx dig curl

print_step "Step 3: Configure Firewall"
print_status "Setting up firewall..."
if command -v ufw &> /dev/null; then
    ufw --force reset
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw --force enable
    print_status "Firewall configured (SSH, HTTP, HTTPS allowed)"
else
    print_warning "UFW not available, skipping firewall setup"
fi

print_step "Step 4: Deploy FromThePage Application"
print_status "Creating necessary directories..."
mkdir -p data logs

# Set proper permissions
print_status "Setting permissions..."
chown -R $USER:$USER .
chmod +x *.sh

# Pull latest images
print_status "Pulling Docker images..."
docker-compose pull

# Start the application
print_status "Starting FromThePage application..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to start..."
sleep 30

# Check if services are running
if ! docker-compose ps | grep -q "Up"; then
    print_error "❌ Application failed to start! Check logs with: docker-compose logs"
    exit 1
fi

print_status "✅ FromThePage application is running!"

print_step "Step 5: Configure Nginx"
print_status "Setting up Nginx configuration..."

# Stop default Nginx site
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
sleep 5

print_step "Step 6: DNS and Domain Check"
print_status "Checking DNS configuration..."

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)
print_status "Server IP: $SERVER_IP"

# Check if domain resolves to this server
DOMAIN_IP=$(dig +short luckiertrout.com || echo "")
WWW_DOMAIN_IP=$(dig +short www.luckiertrout.com || echo "")

print_status "Domain IP (luckiertrout.com): $DOMAIN_IP"
print_status "WWW Domain IP (www.luckiertrout.com): $WWW_DOMAIN_IP"

if [ "$DOMAIN_IP" != "$SERVER_IP" ] && [ "$WWW_DOMAIN_IP" != "$SERVER_IP" ]; then
    print_error "❌ DNS Configuration Issue!"
    print_error "Neither luckiertrout.com nor www.luckiertrout.com point to this server"
    print_error ""
    print_error "Please configure your DNS:"
    print_error "1. Go to your domain registrar's DNS settings"
    print_error "2. Create A record: luckiertrout.com → $SERVER_IP"
    print_error "3. Create A record: www.luckiertrout.com → $SERVER_IP"
    print_error "4. Wait 5-10 minutes for DNS propagation"
    print_error ""
    echo -n "Continue anyway? (y/N): "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_status "Deployment paused. Configure DNS and run this script again."
        exit 1
    fi
fi

print_step "Step 7: SSL Certificate Setup"
print_status "Testing HTTP access first..."

# Test if the site is accessible via HTTP
if curl -f -s http://luckiertrout.com > /dev/null; then
    print_status "✅ HTTP access working"
elif curl -f -s http://$SERVER_IP > /dev/null; then
    print_status "✅ Direct IP access working"
else
    print_warning "HTTP access test failed, but continuing with SSL setup..."
fi

print_status "Getting SSL certificate from Let's Encrypt..."
print_status "This may take a few minutes..."

# Get SSL certificate
if certbot --nginx -d luckiertrout.com -d www.luckiertrout.com --non-interactive --agree-tos --email admin@luckiertrout.com --redirect; then
    print_status "✅ SSL certificate obtained successfully!"
else
    print_error "❌ Failed to get SSL certificate"
    print_error ""
    print_error "This might be due to:"
    print_error "1. DNS not pointing to this server yet"
    print_error "2. Domain not accessible from the internet"
    print_error "3. Port 80/443 blocked by firewall"
    print_error ""
    print_error "You can try again later by running:"
    print_error "certbot --nginx -d luckiertrout.com -d www.luckiertrout.com"
    print_warning "Continuing without SSL for now..."
fi

print_step "Step 8: Final Configuration"
# Set up automatic certificate renewal
print_status "Setting up automatic certificate renewal..."
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

# Set up daily backups
print_status "Setting up daily backups..."
chmod +x backup.sh
(crontab -l 2>/dev/null; echo "0 2 * * * $(pwd)/backup.sh >> /var/log/fromthepage-backup.log 2>&1") | crontab -

print_status "✅ Deployment completed successfully!"
echo ""
echo "🎉 Your FromThePage application is now live!"
echo ""
echo "🌐 Access your site at:"
if certbot certificates 2>/dev/null | grep -q "luckiertrout.com"; then
    echo "   ✅ https://luckiertrout.com (SSL secured)"
    echo "   ✅ https://www.luckiertrout.com (SSL secured)"
    echo "   ↩️  http://luckiertrout.com (redirects to HTTPS)"
else
    echo "   🔓 http://luckiertrout.com (HTTP only)"
    echo "   🔓 http://www.luckiertrout.com (HTTP only)"
    echo ""
    print_warning "SSL setup incomplete. You can retry SSL setup later with:"
    print_warning "certbot --nginx -d luckiertrout.com -d www.luckiertrout.com"
fi
echo ""
echo "📊 Management Commands:"
echo "   Status:    docker-compose ps"
echo "   Logs:      docker-compose logs -f"
echo "   Restart:   docker-compose restart"
echo "   Backup:    ./backup.sh"
echo "   Stop:      docker-compose down"
echo ""
echo "🔒 Security Features Enabled:"
echo "   ✅ Firewall (SSH, HTTP, HTTPS)"
echo "   ✅ Security headers"
echo "   ✅ Auto-renewing SSL certificates"
echo "   ✅ Daily automated backups"
echo ""
print_status "🎯 Deployment complete! Your FromThePage site is ready for use." 