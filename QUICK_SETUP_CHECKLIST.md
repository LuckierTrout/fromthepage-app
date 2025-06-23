# Quick Setup Checklist for luckiertrout.com

## Pre-Deployment Checklist

### ✅ Before You Start
- [ ] DigitalOcean account created
- [ ] SSH key generated and added to DigitalOcean
- [ ] Domain `luckiertrout.com` ready for DNS configuration

### ✅ Step 1: Create DigitalOcean Droplet
- [ ] Create Ubuntu 22.04 LTS droplet
- [ ] Choose plan: **Recommended 4GB RAM, 2 vCPUs ($24/month)**
- [ ] Add your SSH key
- [ ] Note down the droplet IP address: `_____._____._____.____`

### ✅ Step 2: Configure DNS
- [ ] Go to your domain registrar (where you bought luckiertrout.com)
- [ ] Create A record: `@` → Your droplet IP
- [ ] Create A record: `www` → Your droplet IP
- [ ] Wait 5-10 minutes for DNS propagation

### ✅ Step 3: Generate Security Keys
Run these commands locally to generate your security keys:

```bash
# Generate these three keys and save them:
openssl rand -hex 64  # Copy this for FTP_SECRET_KEY_BASE
openssl rand -hex 64  # Copy this for FTP_DEVISE_SECRET_KEY
openssl rand -hex 64  # Copy this for FTP_DEVISE_PEPPER
```

**Save these keys securely - you'll need them in the next step!**

### ✅ Step 4: Update Configuration Files

**CRITICAL**: Before deploying, you MUST update these values in `local.env`:

```bash
# 1. Update admin email (replace with your actual email)
FTP_ADMIN_EMAILS="your-actual-email@gmail.com"

# 2. Set a strong database password
FTP_DATABASE_PASSWORD="YourSecurePassword123!"

# 3. Add the security keys you generated above
FTP_SECRET_KEY_BASE="paste_first_64_char_key_here"
FTP_DEVISE_SECRET_KEY="paste_second_64_char_key_here"  
FTP_DEVISE_PEPPER="paste_third_64_char_key_here"

# 4. Configure SMTP (if using Gmail)
SMTP_USERNAME="your-email@gmail.com"
SMTP_PASSWORD="your-app-password"
```

**Also update `compose.yml`** - make sure the MySQL password matches:
```yaml
- MYSQL_PASSWORD=YourSecurePassword123!  # Same as FTP_DATABASE_PASSWORD
```

## Deployment Commands

### ✅ Step 5: Connect and Deploy

```bash
# 1. Connect to your droplet
ssh root@YOUR_DROPLET_IP

# 2. Upload your code (choose one method)
# Method A: Using git
git clone https://github.com/yourusername/fromthepage-app.git
cd fromthepage-app

# Method B: Using SCP (from your local machine)
scp -r . root@YOUR_DROPLET_IP:/opt/fromthepage-app
ssh root@YOUR_DROPLET_IP
cd /opt/fromthepage-app

# 3. Run deployment
chmod +x deploy-to-digitalocean.sh
./deploy-to-digitalocean.sh
```

### ✅ Step 6: Verify Deployment

```bash
# Check if services are running
docker-compose ps

# View logs if needed
docker-compose logs -f

# Test in browser
# Go to: http://YOUR_DROPLET_IP
```

### ✅ Step 7: Set Up SSL (Production Ready)

```bash
# Install Nginx and Certbot
apt install -y nginx certbot python3-certbot-nginx

# Create Nginx config
nano /etc/nginx/sites-available/fromthepage
```

Paste this configuration:
```nginx
server {
    listen 80;
    server_name luckiertrout.com www.luckiertrout.com;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site and get SSL
ln -s /etc/nginx/sites-available/fromthepage /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx
certbot --nginx -d luckiertrout.com -d www.luckiertrout.com

# Update Docker to use port 8080
# Edit compose.yml: change "80:80" to "8080:80"
nano compose.yml
docker-compose down && docker-compose up -d
```

### ✅ Step 8: Final Security Setup

```bash
# Set up firewall
apt install -y ufw
ufw allow ssh
ufw allow http  
ufw allow https
ufw --force enable

# Set up daily backups
chmod +x backup.sh
crontab -e
# Add: 0 2 * * * /opt/fromthepage-app/backup.sh >> /var/log/fromthepage-backup.log 2>&1
```

## Final Check

### ✅ Your site should now be live at:
- [ ] **HTTP**: http://luckiertrout.com
- [ ] **HTTPS**: https://luckiertrout.com (after SSL setup)

### ✅ Maintenance Commands
```bash
# Check status
docker-compose ps

# View logs  
docker-compose logs -f

# Restart
docker-compose restart

# Create backup
./backup.sh
```

## Troubleshooting

**If something goes wrong:**

1. **Check logs**: `docker-compose logs`
2. **Verify config**: Make sure passwords match in `local.env` and `compose.yml`
3. **Check DNS**: Use `nslookup luckiertrout.com` to verify DNS
4. **Check firewall**: `ufw status`
5. **Check services**: `docker-compose ps`

---

## 🎉 Success!

Once complete, your FromThePage application will be running at:
- **https://luckiertrout.com** (with SSL)
- **https://www.luckiertrout.com** (with SSL)

**Remember to:**
- Keep your droplet updated: `apt update && apt upgrade -y`
- Monitor your backups
- Check logs regularly
- Keep your security keys safe! 