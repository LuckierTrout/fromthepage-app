#!/bin/bash

# FromThePage Elasticsearch Setup Script
# This script sets up Elasticsearch with your existing FromThePage deployment

set -e

echo "🔍 FromThePage Elasticsearch Setup"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "compose.yml" ]; then
    print_error "compose.yml not found! Please run this script from your FromThePage directory."
    exit 1
fi

print_step "Step 1: Choose Elasticsearch Deployment Option"
echo ""
echo "You have two options for Elasticsearch:"
echo "1. Self-hosted (using Docker containers)"
echo "2. Elastic Cloud (managed service)"
echo ""
read -p "Which option would you like? (1 for self-hosted, 2 for cloud): " choice

if [ "$choice" = "1" ]; then
    print_step "Step 2: Setting up Self-hosted Elasticsearch"
    
    # Check available memory
    TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    print_status "Available memory: ${TOTAL_MEM}MB"
    
    if [ "$TOTAL_MEM" -lt 2048 ]; then
        print_warning "Your server has less than 2GB RAM. Elasticsearch may struggle."
        print_warning "Consider upgrading to a 4GB droplet or using Elastic Cloud."
        echo ""
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Backup current compose file
    print_status "Backing up current compose.yml..."
    cp compose.yml compose.yml.backup
    
    # Replace with Elasticsearch-enabled version
    print_status "Updating compose.yml with Elasticsearch..."
    cp compose.elasticsearch.yml compose.yml
    
    # Set vm.max_map_count for Elasticsearch
    print_status "Configuring system for Elasticsearch..."
    sysctl -w vm.max_map_count=262144
    echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
    
    # Update local.env
    print_status "Updating local.env for self-hosted Elasticsearch..."
    sed -i 's/ELASTIC_ENABLED=false/ELASTIC_ENABLED=false/' local.env
    
    print_step "Step 3: Starting Elasticsearch"
    print_status "Pulling Elasticsearch image..."
    docker-compose pull elasticsearch
    
    print_status "Starting Elasticsearch container..."
    docker-compose up -d elasticsearch
    
    print_status "Waiting for Elasticsearch to start..."
    sleep 30
    
    # Test Elasticsearch connection
    if curl -f -s http://localhost:9200 > /dev/null; then
        print_status "✅ Elasticsearch is running!"
        curl http://localhost:9200
    else
        print_error "❌ Elasticsearch failed to start"
        print_error "Check logs: docker-compose logs elasticsearch"
        exit 1
    fi
    
elif [ "$choice" = "2" ]; then
    print_step "Step 2: Setting up Elastic Cloud"
    print_status "Please complete these steps:"
    echo ""
    echo "1. Go to https://cloud.elastic.co/"
    echo "2. Create an account or sign in"
    echo "3. Create a new deployment"
    echo "4. Copy your Cloud ID and API Key"
    echo ""
    
    read -p "Enter your Elastic Cloud ID: " cloud_id
    read -p "Enter your Elastic API Key: " api_key
    
    if [ -z "$cloud_id" ] || [ -z "$api_key" ]; then
        print_error "Cloud ID and API Key are required!"
        exit 1
    fi
    
    print_status "Updating local.env for Elastic Cloud..."
    sed -i "s|ELASTICSEARCH_URL=http://elasticsearch:9200|# ELASTICSEARCH_URL=http://elasticsearch:9200|" local.env
    sed -i "s|# ELASTIC_CLOUD_ID=\"your_cloud_id_here\"|ELASTIC_CLOUD_ID=\"$cloud_id\"|" local.env
    sed -i "s|# ELASTIC_API_KEY=\"your_api_key_here\"|ELASTIC_API_KEY=\"$api_key\"|" local.env
    
else
    print_error "Invalid choice. Please run the script again."
    exit 1
fi

print_step "Step 4: Initialize Elasticsearch for FromThePage"
print_status "Restarting FromThePage with new configuration..."
docker-compose up -d fromthepage

print_status "Waiting for FromThePage to start..."
sleep 20

print_status "Setting up Elasticsearch indices..."
print_warning "Note: The following commands will be available once FromThePage supports them:"
echo ""
echo "# Reset Elasticsearch (if needed)"
echo "docker-compose exec fromthepage bundle exec rake fromthepage:es_reset"
echo ""
echo "# Initialize Elasticsearch configuration"
echo "docker-compose exec fromthepage bundle exec rake fromthepage:es_init"
echo ""
echo "# Reindex all content (this may take hours for large datasets)"
echo "docker-compose exec fromthepage bundle exec rake fromthepage:es_reindex"
echo ""
echo "# Set up index aliases"
echo "docker-compose exec fromthepage bundle exec rake fromthepage:es_rollover"
echo ""

print_step "Step 5: Enable Elasticsearch"
print_warning "Elasticsearch is configured but not yet enabled."
print_warning "To enable it, change ELASTIC_ENABLED=true in local.env after indexing is complete."

echo ""
print_status "✅ Elasticsearch setup completed!"
echo ""
echo "📋 Next Steps:"
echo "1. Wait for the initial indexing to complete"
echo "2. Set ELASTIC_ENABLED=true in local.env"
echo "3. Restart FromThePage: docker-compose restart fromthepage"
echo ""
echo "🔍 Useful Commands:"
echo "   Check Elasticsearch status: curl http://localhost:9200/_cluster/health"
echo "   View FromThePage logs: docker-compose logs -f fromthepage"
echo "   Check Elasticsearch logs: docker-compose logs -f elasticsearch" 