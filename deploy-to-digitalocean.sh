#!/bin/bash

# FromThePage DigitalOcean Deployment Script
# This script helps deploy the FromThePage application to a DigitalOcean droplet

set -e

echo "🚀 FromThePage DigitalOcean Deployment Script"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running on DigitalOcean droplet
if [ -f /etc/digitalocean ]; then
    print_status "Running on DigitalOcean droplet"
else
    print_warning "Not detected as DigitalOcean droplet, continuing anyway..."
fi

# Update system packages
print_status "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    print_status "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
else
    print_status "Docker already installed"
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    print_status "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    print_status "Docker Compose already installed"
fi

# Check if local.env exists and has been configured
if [ ! -f "local.env" ]; then
    print_error "local.env file not found!"
    print_error "Please copy local.env.template to local.env and configure it first."
    exit 1
fi

# Check for placeholder values in local.env
if grep -q "yourdomain.com\|generate_64_char_hex_key_here\|secure_password_here" local.env; then
    print_error "Please configure local.env with your actual values before deploying!"
    print_error "Replace all placeholder values (yourdomain.com, generate_64_char_hex_key_here, etc.)"
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p data logs

# Set proper permissions
print_status "Setting permissions..."
sudo chown -R $USER:$USER .
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
if docker-compose ps | grep -q "Up"; then
    print_status "✅ Application deployed successfully!"
    echo ""
    echo "🌐 Your FromThePage application should be accessible at:"
    echo "   http://$(curl -s ifconfig.me)"
    echo ""
    echo "📊 To check status: docker-compose ps"
    echo "📋 To view logs: docker-compose logs -f"
    echo "🔄 To restart: docker-compose restart"
    echo "🛑 To stop: docker-compose down"
    echo ""
    print_warning "Remember to:"
    print_warning "1. Configure your domain DNS to point to this server"
    print_warning "2. Set up SSL/HTTPS (recommended: use Nginx proxy with Let's Encrypt)"
    print_warning "3. Configure firewall rules (allow ports 80, 443, 22)"
    print_warning "4. Set up regular backups for your data"
else
    print_error "❌ Deployment failed! Check logs with: docker-compose logs"
    exit 1
fi 