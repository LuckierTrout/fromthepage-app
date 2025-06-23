# FromThePage DigitalOcean Deployment Guide

This guide will walk you through deploying your FromThePage application to DigitalOcean step by step.

## Prerequisites

- DigitalOcean account
- Domain name (optional but recommended)
- Basic familiarity with command line
- SSH key pair for secure access

## Step 1: Create a DigitalOcean Droplet

1. **Log into DigitalOcean** and click "Create" → "Droplets"

2. **Choose an image**: Select "Ubuntu 22.04 LTS"

3. **Choose a plan**: 
   - **Minimum**: Basic plan with 2 GB RAM, 1 vCPU ($12/month)
   - **Recommended**: Basic plan with 4 GB RAM, 2 vCPUs ($24/month)
   - **For high traffic**: 8 GB RAM, 4 vCPUs ($48/month)

4. **Choose a datacenter region**: Select the region closest to your users

5. **Authentication**: Add your SSH key (recommended) or create a password

6. **Finalize**: Give your droplet a name (e.g., "fromthepage-prod") and click "Create Droplet"

## Step 2: Configure Your Domain (Optional but Recommended)

If you have a domain name:

1. Go to your domain registrar's DNS settings
2. Create an A record pointing to your droplet's IP address:
   - **Name**: `@` (for root domain) or `www`
   - **Type**: A
   - **Value**: Your droplet's IP address
   - **TTL**: 300 (5 minutes)

## Step 3: Connect to Your Droplet

```bash
ssh root@YOUR_DROPLET_IP
```

Replace `YOUR_DROPLET_IP` with your actual droplet IP address.

## Step 4: Upload Your Application

### Option A: Using Git (Recommended)

1. **Install Git** (if not already installed):
   ```bash
   apt update && apt install -y git
   ```

2. **Clone your repository**:
   ```bash
   git clone https://github.com/yourusername/fromthepage-app.git
   cd fromthepage-app
   ```

### Option B: Using SCP

From your local machine:
```bash
scp -r /path/to/your/fromthepage-app root@YOUR_DROPLET_IP:/opt/
ssh root@YOUR_DROPLET_IP
cd /opt/fromthepage-app
```

## Step 5: Configure Your Application

1. **Generate security keys**:
   ```bash
   # Generate three 64-character hex keys
   openssl rand -hex 64  # For FTP_SECRET_KEY_BASE
   openssl rand -hex 64  # For FTP_DEVISE_SECRET_KEY  
   openssl rand -hex 64  # For FTP_DEVISE_PEPPER
   ```

2. **Edit the environment file**:
   ```bash
   cp local.env.template local.env
   nano local.env
   ```

3. **Update the following values in `local.env`**:
   ```bash
   # Replace with your actual values
   FTP_ADMIN_EMAILS="admin@luckiertrout.com"
   FTP_SENDING_EMAIL_ADDRESS="FromThePage <noreply@luckiertrout.com>"
   FTP_HOSTNAME="luckiertrout.com"  # or your droplet IP
   
   # Database (use a strong password)
   FTP_DATABASE_PASSWORD="your_secure_database_password"
   
   # Security keys (use the ones you generated above)
   FTP_SECRET_KEY_BASE="your_64_char_hex_key_1"
   FTP_DEVISE_SECRET_KEY="your_64_char_hex_key_2"
   FTP_DEVISE_PEPPER="your_64_char_hex_key_3"
   
   # SMTP settings (configure based on your email provider)
   SMTP_HOST="smtp.gmail.com"
   SMTP_PORT=587
   # Add these if using Gmail or other SMTP
   # SMTP_USERNAME="your-email@gmail.com"
   # SMTP_PASSWORD="your-app-password"
   ```

4. **Update compose.yml** to match your database password:
   ```bash
   nano compose.yml
   ```
   Make sure the `MYSQL_PASSWORD` matches your `FTP_DATABASE_PASSWORD`.

## Step 6: Deploy the Application

1. **Make the deployment script executable**:
   ```bash
   chmod +x deploy-to-digitalocean.sh
   ```

2. **Run the deployment script**:
   ```bash
   ./deploy-to-digitalocean.sh
   ```

   This script will:
   - Update the system
   - Install Docker and Docker Compose
   - Pull the application images
   - Start your FromThePage application

3. **Wait for deployment to complete** (usually 2-5 minutes)

## Step 7: Verify Your Deployment

1. **Check if services are running**:
   ```bash
   docker-compose ps
   ```

2. **View logs** if needed:
   ```bash
   docker-compose logs -f
   ```

3. **Test your application**:
   - Open your browser and go to `http://YOUR_DROPLET_IP` or `http://yourdomain.com`
   - You should see the FromThePage homepage

## Step 8: Set Up SSL/HTTPS (Recommended)

For production use, you should set up SSL. Here's a quick setup using Nginx and Let's Encrypt:

1. **Install Nginx**:
   ```bash
   apt install -y nginx certbot python3-certbot-nginx
   ```

2. **Create Nginx configuration**:
   ```bash
   nano /etc/nginx/sites-available/fromthepage
   ```

   Add this configuration:
   ```nginx
   server {
       listen 80;
       server_name luckiertrout.com www.luckiertrout.com;
       
       location / {
           proxy_pass http://localhost:80;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
           proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
           proxy_set_header X-Forwarded-Proto $scheme;
       }
   }
   ```

3. **Enable the site**:
   ```bash
   ln -s /etc/nginx/sites-available/fromthepage /etc/nginx/sites-enabled/
   nginx -t
   systemctl reload nginx
   ```

4. **Get SSL certificate**:
   ```bash
   certbot --nginx -d luckiertrout.com -d www.luckiertrout.com
   ```

5. **Update your compose.yml** to use port 8080 instead of 80:
   ```yaml
   ports:
   - "8080:80"
   ```

6. **Update Nginx config** to proxy to port 8080:
   ```nginx
   proxy_pass http://localhost:8080;
   ```

7. **Restart services**:
   ```bash
   docker-compose down && docker-compose up -d
   systemctl reload nginx
   ```

## Step 9: Set Up Firewall

```bash
# Install and configure UFW firewall
apt install -y ufw

# Allow SSH, HTTP, and HTTPS
ufw allow ssh
ufw allow http
ufw allow https

# Enable firewall
ufw --force enable

# Check status
ufw status
```

## Step 10: Set Up Backups

1. **Make backup script executable**:
   ```bash
   chmod +x backup.sh
   ```

2. **Test the backup**:
   ```bash
   ./backup.sh
   ```

3. **Set up automated daily backups**:
   ```bash
   crontab -e
   ```
   
   Add this line for daily backups at 2 AM:
   ```
   0 2 * * * /opt/fromthepage-app/backup.sh >> /var/log/fromthepage-backup.log 2>&1
   ```

## Maintenance Commands

- **View application status**: `docker-compose ps`
- **View logs**: `docker-compose logs -f`
- **Restart application**: `docker-compose restart`
- **Stop application**: `docker-compose down`
- **Start application**: `docker-compose up -d`
- **Update application**: `docker-compose pull && docker-compose up -d`
- **Create backup**: `./backup.sh`

## Troubleshooting

### Application won't start
1. Check logs: `docker-compose logs`
2. Verify environment variables in `local.env`
3. Ensure database password matches in both files

### Can't access the application
1. Check if services are running: `docker-compose ps`
2. Verify firewall settings: `ufw status`
3. Check if the correct ports are exposed

### Database issues
1. Check MySQL logs: `docker-compose logs mysql`
2. Verify database credentials in `local.env`
3. Ensure database volume has proper permissions

### Performance issues
1. Monitor resources: `docker stats`
2. Consider upgrading to a larger droplet
3. Check application logs for errors

## Security Best Practices

1. **Regular updates**: Keep your droplet updated
   ```bash
   apt update && apt upgrade -y
   ```

2. **Strong passwords**: Use strong, unique passwords for all accounts

3. **SSH key authentication**: Disable password authentication for SSH

4. **Regular backups**: Ensure your backup script runs regularly

5. **Monitor logs**: Regularly check application and system logs

6. **SSL/HTTPS**: Always use HTTPS in production

## Support

If you encounter issues:
1. Check the logs: `docker-compose logs`
2. Review this guide for missed steps
3. Check the FromThePage documentation
4. Contact your system administrator

---

**Congratulations!** Your FromThePage application should now be running on DigitalOcean. Remember to regularly backup your data and keep your system updated. 