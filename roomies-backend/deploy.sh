#!/bin/bash

# Deployment script for Roomies Backend

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
EC2_HOST="${1:-54.93.77.238}"
EC2_USER="ec2-user"
KEY_PATH="${HOME}/.ssh/roomies-backend.pem"
REMOTE_DIR="/opt/roomies"

echo -e "${GREEN}Starting deployment to EC2 instance: ${EC2_HOST}${NC}"

# Build the TypeScript project
echo -e "${YELLOW}Building TypeScript project...${NC}"
npm run build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! Aborting deployment.${NC}"
    exit 1
fi

# Create deployment package
echo -e "${YELLOW}Creating deployment package...${NC}"
rm -rf deploy-package
mkdir -p deploy-package

# Copy necessary files
cp -r dist deploy-package/
cp package*.json deploy-package/
cp ecosystem.config.js deploy-package/
cp .env.production deploy-package/.env
cp -r src/migrations deploy-package/migrations 2>/dev/null || true

# Create tarball
tar -czf roomies-backend-deploy.tar.gz -C deploy-package .

# Upload to EC2
echo -e "${YELLOW}Uploading to EC2...${NC}"
scp -i ${KEY_PATH} roomies-backend-deploy.tar.gz ${EC2_USER}@${EC2_HOST}:/tmp/

# Deploy on EC2
echo -e "${YELLOW}Deploying on EC2...${NC}"
ssh -i ${KEY_PATH} ${EC2_USER}@${EC2_HOST} << 'EOF'
set -e

# Source NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Create directories
sudo mkdir -p /opt/roomies/logs
sudo chown -R ec2-user:ec2-user /opt/roomies

# Extract deployment package
cd /opt/roomies
tar -xzf /tmp/roomies-backend-deploy.tar.gz
rm /tmp/roomies-backend-deploy.tar.gz

# Install dependencies
echo "Installing dependencies..."
npm ci --production

# Stop existing PM2 process if running
pm2 stop roomies-backend 2>/dev/null || true
pm2 delete roomies-backend 2>/dev/null || true

# Start the application with PM2
echo "Starting application with PM2..."
pm2 start ecosystem.config.js --env production
pm2 save

# Show status
pm2 status
echo "Deployment complete!"
EOF

# Cleanup
rm -rf deploy-package roomies-backend-deploy.tar.gz

echo -e "${GREEN}Deployment completed successfully!${NC}"
echo -e "${GREEN}Backend should be accessible at: http://${EC2_HOST}:3001${NC}"
