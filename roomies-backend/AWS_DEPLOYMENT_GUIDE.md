# 🚀 AWS Deployment Guide for Roomies

This guide will help you deploy the Roomies backend to AWS using the free tier services.

## 📋 Prerequisites

1. **AWS Account**: Sign up for AWS Free Tier at https://aws.amazon.com/free/
2. **AWS CLI**: Install from https://aws.amazon.com/cli/
3. **Node.js 18+**: Required for the backend
4. **PostgreSQL Client** (optional): For database management

## 🏗️ AWS Services Overview

### Free Tier Limits
- **EC2**: 750 hours/month (t2.micro or t3.micro)
- **RDS**: 750 hours/month (db.t3.micro), 20GB storage
- **ElastiCache**: 750 hours/month (cache.t3.micro)
- **S3**: 5GB storage, 20,000 GET requests, 2,000 PUT requests
- **Cognito**: 50,000 MAUs free
- **SES**: 62,000 emails/month (from EC2)
- **CloudWatch**: Basic monitoring free

## 🔧 Step 1: Initial AWS Setup

### Install and Configure AWS CLI

```bash
# Install AWS CLI (macOS)
brew install awscli

# Or download from https://aws.amazon.com/cli/

# Configure AWS credentials
aws configure
# Enter your:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region (e.g., us-east-1)
# - Default output format (json)
```

## 🎯 Step 2: Automated Setup

We've created a script to automate most of the AWS setup:

```bash
cd roomies-backend
chmod +x scripts/aws-setup.sh
./scripts/aws-setup.sh
```

This script will:
1. Create an IAM user with necessary permissions
2. Set up S3 bucket for file storage
3. Create RDS PostgreSQL instance
4. Set up ElastiCache Redis cluster
5. Configure Cognito for authentication
6. Set up SES for email

## 🔨 Step 3: Manual Configuration

### 3.1 Wait for Resources to be Ready

RDS and ElastiCache take 5-10 minutes to provision. Check their status:

```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier roomies-db \
  --query 'DBInstances[0].DBInstanceStatus' \
  --output text

# Should show "available" when ready

# Get RDS endpoint
aws rds describe-db-instances \
  --db-instance-identifier roomies-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# Check ElastiCache status
aws elasticache describe-cache-clusters \
  --cache-cluster-id roomies-cache \
  --query 'CacheClusters[0].CacheClusterStatus' \
  --output text

# Should show "available" when ready

# Get ElastiCache endpoint
aws elasticache describe-cache-clusters \
  --cache-cluster-id roomies-cache \
  --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' \
  --output text
```

### 3.2 Update Environment Variables

Update your `.env` file with the AWS endpoints:

```bash
# Copy AWS configuration
cat .env.aws >> .env

# Edit .env and update the endpoint URLs
nano .env
```

Your `.env` should now include:
```env
AWS_ENABLED=true
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key

AWS_RDS_HOST=your-rds-endpoint.rds.amazonaws.com
AWS_RDS_PORT=5432
AWS_RDS_DATABASE=roomies_production
AWS_RDS_USERNAME=roomiesadmin
AWS_RDS_PASSWORD=your_password

AWS_S3_BUCKET=roomies-storage-your-account-id

AWS_ELASTICACHE_HOST=your-cache-endpoint.cache.amazonaws.com
AWS_ELASTICACHE_PORT=6379
```

### 3.3 Security Group Configuration

Allow your backend to access RDS and ElastiCache:

```bash
# Get default VPC ID
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

# Create security group for backend
aws ec2 create-security-group \
  --group-name roomies-backend \
  --description "Security group for Roomies backend" \
  --vpc-id $VPC_ID

# Allow HTTP/HTTPS traffic
aws ec2 authorize-security-group-ingress \
  --group-name roomies-backend \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-name roomies-backend \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

# Allow backend port
aws ec2 authorize-security-group-ingress \
  --group-name roomies-backend \
  --protocol tcp \
  --port 3000 \
  --cidr 0.0.0.0/0
```

## 🚀 Step 4: Deploy Backend to EC2

### 4.1 Launch EC2 Instance

```bash
# Create key pair for SSH access
aws ec2 create-key-pair \
  --key-name roomies-key \
  --query 'KeyMaterial' \
  --output text > roomies-key.pem

chmod 400 roomies-key.pem

# Launch EC2 instance
aws ec2 run-instances \
  --image-id ami-0c02fb55731490381 \
  --instance-type t3.micro \
  --key-name roomies-key \
  --security-group-ids $(aws ec2 describe-security-groups --group-names roomies-backend --query 'SecurityGroups[0].GroupId' --output text) \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=roomies-backend}]' \
  --user-data '#!/bin/bash
    yum update -y
    yum install -y nodejs npm git
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
    . ~/.nvm/nvm.sh
    nvm install 18
    nvm use 18'
```

### 4.2 Deploy Code to EC2

```bash
# Get instance public IP
INSTANCE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=roomies-backend" "Name=instance-state-name,Values=running" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' \
  --output text)

# SSH into instance
ssh -i roomies-key.pem ec2-user@$INSTANCE_IP

# On the EC2 instance:
# Clone your repository
git clone https://github.com/yourusername/roomies.git
cd roomies/roomies-backend

# Install dependencies
npm install

# Copy .env file (you'll need to transfer it securely)
# Option 1: Use SCP from your local machine
exit  # Exit SSH first
scp -i roomies-key.pem .env ec2-user@$INSTANCE_IP:~/roomies/roomies-backend/
ssh -i roomies-key.pem ec2-user@$INSTANCE_IP

# Build the backend
cd roomies/roomies-backend
npm run build

# Install PM2 for process management
npm install -g pm2

# Start the backend with PM2
pm2 start dist/server.js --name roomies-backend
pm2 save
pm2 startup
```

## 📱 Step 5: Update iOS App Configuration

Update your iOS app to point to the AWS backend:

```swift
// In your iOS app configuration
let baseURL = "http://your-ec2-public-ip:3000/api"
```

## 🔒 Step 6: Security Best Practices

### 6.1 Enable HTTPS (Recommended)

Use AWS Certificate Manager and Application Load Balancer:

```bash
# Request SSL certificate
aws acm request-certificate \
  --domain-name roomies.yourdomain.com \
  --validation-method DNS

# Create Application Load Balancer (additional cost)
# This is beyond free tier but recommended for production
```

### 6.2 Backup Configuration

```bash
# Enable automated RDS backups (already configured)
# Create S3 lifecycle policies for old files

aws s3api put-bucket-lifecycle-configuration \
  --bucket roomies-storage-your-account-id \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "DeleteOldFiles",
      "Status": "Enabled",
      "Expiration": {
        "Days": 90
      }
    }]
  }'
```

## 📊 Step 7: Monitoring

### CloudWatch Dashboard

```bash
# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name RoomiesDashboard \
  --dashboard-body file://cloudwatch-dashboard.json
```

### Set up Alarms

```bash
# CPU utilization alarm for EC2
aws cloudwatch put-metric-alarm \
  --alarm-name roomies-high-cpu \
  --alarm-description "Alarm when CPU exceeds 70%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 70 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## 🧹 Cleanup (if needed)

To avoid charges, clean up resources when not needed:

```bash
# Terminate EC2 instance
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances --filters "Name=tag:Name,Values=roomies-backend" --query 'Reservations[0].Instances[0].InstanceId' --output text)

# Delete RDS instance
aws rds delete-db-instance --db-instance-identifier roomies-db --skip-final-snapshot

# Delete ElastiCache cluster
aws elasticache delete-cache-cluster --cache-cluster-id roomies-cache

# Delete S3 bucket (first empty it)
aws s3 rm s3://roomies-storage-your-account-id --recursive
aws s3 rb s3://roomies-storage-your-account-id
```

## 🆘 Troubleshooting

### Common Issues and Solutions

1. **Cannot connect to RDS**
   - Check security group rules
   - Ensure RDS is in the same VPC as EC2
   - Verify credentials

2. **ElastiCache connection timeout**
   - ElastiCache must be in the same VPC
   - Check security group allows Redis port (6379)

3. **S3 access denied**
   - Verify IAM permissions
   - Check bucket policies
   - Ensure correct region

4. **High AWS bills**
   - Monitor free tier usage in AWS Console
   - Set up billing alerts
   - Use AWS Cost Explorer

## 📚 Additional Resources

- [AWS Free Tier](https://aws.amazon.com/free/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Node.js on AWS](https://aws.amazon.com/getting-started/hands-on/deploy-nodejs-web-app/)
- [RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)

## 🎉 Congratulations!

Your Roomies backend is now running on AWS! The setup includes:
- ✅ Scalable compute with EC2
- ✅ Managed PostgreSQL with RDS
- ✅ Redis caching with ElastiCache
- ✅ File storage with S3
- ✅ User authentication ready with Cognito
- ✅ Email notifications with SES
- ✅ Monitoring with CloudWatch

Remember to:
- Monitor your free tier usage
- Set up billing alerts
- Regularly update and patch your instances
- Back up your data
- Review security settings periodically
