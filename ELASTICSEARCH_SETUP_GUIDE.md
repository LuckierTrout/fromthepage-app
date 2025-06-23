# FromThePage Elasticsearch Setup Guide

## 🔍 **What is Elasticsearch for FromThePage?**

Based on the [FromThePage ElasticSearch Implementation documentation](https://github.com/benwbrum/fromthepage/wiki/ElasticSearch-Implementation-(from-Dan)), Elasticsearch provides:

- ✅ **Reduced database load** - Search queries don't hit MySQL
- ✅ **Complex queries** - Advanced search capabilities
- ✅ **Relevance scoring** - Better search result ranking
- ✅ **Multilingual support** - Search in multiple languages
- ✅ **Synonyms & stopwords** - Smart search features

## 🚀 **Deployment Options**

### **Option 1: Self-hosted Elasticsearch (Cost-effective)**
- **Pros**: Lower cost, full control, integrated with your Docker setup
- **Cons**: Requires server maintenance, uses server resources
- **Recommended for**: Development, testing, small-medium deployments
- **Memory requirement**: Minimum 2GB RAM (4GB+ recommended)

### **Option 2: Elastic Cloud (Managed)**
- **Pros**: Fully managed, scalable, enterprise features
- **Cons**: Monthly cost (~$16+ per month)
- **Recommended for**: Production, large datasets, enterprise use

## 📋 **Prerequisites**

Before setting up Elasticsearch:

- ✅ FromThePage already running on DigitalOcean
- ✅ At least 4GB RAM on your droplet (for self-hosted)
- ✅ SSH access to your server

## 🛠️ **Setup Process**

### **Step 1: Prepare for Elasticsearch**

```bash
# SSH into your DigitalOcean droplet
ssh root@134.199.196.205

# Navigate to your FromThePage directory
cd /opt/fromthepage-app

# Update your repository with new Elasticsearch files
git pull origin main
```

### **Step 2: Run the Elasticsearch Setup Script**

```bash
# Run the interactive setup script
./deploy-elasticsearch.sh
```

The script will:
1. Ask you to choose between self-hosted or Elastic Cloud
2. Configure your environment appropriately
3. Set up the necessary Docker containers (if self-hosted)
4. Provide next steps for indexing

### **Step 3: For Self-hosted Option**

If you chose self-hosted, the script will:
- Add Elasticsearch container to your Docker setup
- Configure system settings for Elasticsearch
- Start the Elasticsearch service
- Test the connection

**Your services will then be:**
```
FromThePage:    http://luckiertrout.com (port 8080)
MySQL:          Internal (port 3306)
Elasticsearch:  Internal (port 9200)
Nginx:          Public (ports 80/443)
```

### **Step 4: For Elastic Cloud Option**

If you chose Elastic Cloud:
1. Go to https://cloud.elastic.co/
2. Create an account and deployment
3. Copy your Cloud ID and API Key
4. Enter them when prompted by the script

## 🔧 **Configuration Files Created/Modified**

### **New Files:**
- `compose.elasticsearch.yml` - Docker compose with Elasticsearch
- `deploy-elasticsearch.sh` - Setup script
- `ELASTICSEARCH_SETUP_GUIDE.md` - This guide

### **Modified Files:**
- `local.env` - Added Elasticsearch environment variables
- `compose.yml` - Will be replaced with Elasticsearch version

## 📊 **Elasticsearch Management Commands**

### **Check Elasticsearch Status:**
```bash
# Check if Elasticsearch is running
curl http://localhost:9200

# Check cluster health
curl http://localhost:9200/_cluster/health

# View Elasticsearch logs
docker-compose logs -f elasticsearch
```

### **FromThePage Elasticsearch Commands:**
```bash
# Initialize Elasticsearch indices
docker-compose exec fromthepage bundle exec rake fromthepage:es_init

# Reset Elasticsearch (clears all data)
docker-compose exec fromthepage bundle exec rake fromthepage:es_reset

# Reindex all content (may take hours)
docker-compose exec fromthepage bundle exec rake fromthepage:es_reindex

# Set up index aliases
docker-compose exec fromthepage bundle exec rake fromthepage:es_rollover
```

## ⚙️ **Configuration Variables in local.env**

```bash
# Enable/disable Elasticsearch
ELASTIC_ENABLED=false  # Set to true after indexing

# For self-hosted Elasticsearch
ELASTICSEARCH_URL=http://elasticsearch:9200

# For Elastic Cloud (comment out ELASTICSEARCH_URL)
# ELASTIC_CLOUD_ID="your_cloud_id_here"
# ELASTIC_API_KEY="your_api_key_here"

# Development suffix (optional)
ELASTIC_SUFFIX=dev
```

## 🔄 **Enabling Elasticsearch**

**Important**: Don't enable Elasticsearch until after initial indexing!

1. **First, index your content:**
   ```bash
   docker-compose exec fromthepage bundle exec rake fromthepage:es_reindex
   ```

2. **Then enable Elasticsearch:**
   ```bash
   # Edit local.env
   nano local.env
   
   # Change this line:
   ELASTIC_ENABLED=true
   
   # Restart FromThePage
   docker-compose restart fromthepage
   ```

## 🔍 **Testing Elasticsearch**

### **Test Elasticsearch is Running:**
```bash
curl http://localhost:9200
# Should return JSON with cluster info
```

### **Test FromThePage Integration:**
1. Go to your FromThePage site: https://luckiertrout.com
2. Use the search functionality
3. Check logs for Elasticsearch queries:
   ```bash
   docker-compose logs -f fromthepage | grep -i elastic
   ```

## 📈 **Resource Requirements**

### **Self-hosted Elasticsearch:**
- **Minimum**: 2GB RAM, 1GB disk space
- **Recommended**: 4GB+ RAM, 10GB+ disk space
- **Production**: 8GB+ RAM, SSD storage

### **DigitalOcean Droplet Recommendations:**
- **Current (4GB)**: Can handle small-medium datasets
- **Upgrade to 8GB**: For larger datasets or better performance
- **16GB+**: For enterprise-level usage

## 🛡️ **Security Considerations**

### **Self-hosted Setup:**
- Elasticsearch runs on internal Docker network (not exposed publicly)
- No authentication enabled (secure by network isolation)
- Access only through FromThePage application

### **Elastic Cloud:**
- Fully managed security
- API key authentication
- HTTPS encryption

## 🔧 **Troubleshooting**

### **Elasticsearch Won't Start:**
```bash
# Check logs
docker-compose logs elasticsearch

# Common issues:
# 1. Insufficient memory
# 2. vm.max_map_count not set
# 3. Port conflicts

# Fix vm.max_map_count:
sudo sysctl -w vm.max_map_count=262144
```

### **FromThePage Can't Connect:**
```bash
# Test connection from FromThePage container
docker-compose exec fromthepage curl http://elasticsearch:9200

# Check environment variables
docker-compose exec fromthepage env | grep ELASTIC
```

### **Indexing Takes Too Long:**
```bash
# Check indexing progress
docker-compose logs -f fromthepage

# For large datasets, consider:
# 1. Upgrading server resources
# 2. Using Elastic Cloud
# 3. Indexing in smaller batches
```

## 📋 **Next Steps After Setup**

1. **Monitor Performance**: Watch server resources during indexing
2. **Test Search**: Verify search functionality works as expected
3. **Backup Strategy**: Include Elasticsearch data in backups
4. **Consider Scaling**: Upgrade server if needed

## 🎯 **Expected Benefits**

After successful setup:
- ✅ Faster search responses
- ✅ Reduced database load
- ✅ Better search relevance
- ✅ Advanced search features
- ✅ Multilingual search support

---

**Ready to set up Elasticsearch?** Run `./deploy-elasticsearch.sh` on your DigitalOcean droplet! 