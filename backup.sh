#!/bin/bash

# FromThePage Backup Script for DigitalOcean
# This script creates backups of your FromThePage application data

set -e

# Configuration
BACKUP_DIR="/opt/fromthepage-backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="fromthepage_backup_${DATE}"

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

# Create backup directory
print_status "Creating backup directory..."
sudo mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR"

# Create backup subdirectory
sudo mkdir -p "$BACKUP_NAME"

print_status "Starting backup process..."

# Backup MySQL database
print_status "Backing up MySQL database..."
docker-compose exec -T mysql mysqldump -u fromthepage -pfromthepage fromthepage > "${BACKUP_NAME}/database.sql"

# Backup Docker volumes
print_status "Backing up application data volumes..."
docker run --rm -v fromthepage-app_fromthepage_public_images_working:/data -v "$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/images_working.tar.gz -C /data .
docker run --rm -v fromthepage-app_fromthepage_public_images_uploaded:/data -v "$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/images_uploaded.tar.gz -C /data .
docker run --rm -v fromthepage-app_fromthepage_public_uploads:/data -v "$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/uploads.tar.gz -C /data .
docker run --rm -v fromthepage-app_fromthepage_public_text:/data -v "$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/text.tar.gz -C /data .
docker run --rm -v fromthepage-app_fromthepage_logs:/data -v "$BACKUP_DIR/$BACKUP_NAME":/backup alpine tar czf /backup/logs.tar.gz -C /data .

# Backup configuration files
print_status "Backing up configuration files..."
cp local.env compose.yml "${BACKUP_NAME}/"

# Create final compressed backup
print_status "Creating compressed backup archive..."
tar czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Set proper permissions
sudo chown -R $USER:$USER "$BACKUP_DIR"

print_status "✅ Backup completed successfully!"
print_status "Backup saved as: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"

# Clean up old backups (keep last 7 days)
print_status "Cleaning up old backups (keeping last 7 days)..."
find "$BACKUP_DIR" -name "fromthepage_backup_*.tar.gz" -mtime +7 -delete

print_status "Backup process finished!"
echo ""
echo "📁 Backup location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
echo "💾 To restore from backup, use the restore.sh script" 