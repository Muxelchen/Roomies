#!/bin/bash

# 🚀 AWS Setup Script for Roomies Backend
# This script helps you set up AWS services for the Roomies app

echo "🏠 Roomies AWS Setup Script"
echo "==========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed${NC}"
    echo "Please install AWS CLI first: https://aws.amazon.com/cli/"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI found${NC}"

# Configure AWS credentials if not already configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    echo "You'll need your AWS Access Key ID and Secret Access Key"
    exit 1
fi

echo -e "${GREEN}✅ AWS credentials configured${NC}"

# Get AWS account ID and region
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)

echo ""
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "AWS Region: $AWS_REGION"
echo ""

# Function to create S3 bucket
create_s3_bucket() {
    BUCKET_NAME="roomies-storage-$AWS_ACCOUNT_ID"
    echo "📦 Creating S3 bucket: $BUCKET_NAME"
    
    if aws s3 ls "s3://$BUCKET_NAME" 2>&1 | grep -q 'NoSuchBucket'; then
        if [ "$AWS_REGION" = "us-east-1" ]; then
            aws s3 mb "s3://$BUCKET_NAME"
        else
            aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
        fi
        
        # Enable versioning
        aws s3api put-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --versioning-configuration Status=Enabled
        
        # Set CORS configuration
        aws s3api put-bucket-cors \
            --bucket "$BUCKET_NAME" \
            --cors-configuration '{
                "CORSRules": [{
                    "AllowedHeaders": ["*"],
                    "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
                    "AllowedOrigins": ["*"],
                    "ExposeHeaders": ["ETag"],
                    "MaxAgeSeconds": 3000
                }]
            }'
        
        echo -e "${GREEN}✅ S3 bucket created: $BUCKET_NAME${NC}"
    else
        echo -e "${YELLOW}⚠️  S3 bucket already exists: $BUCKET_NAME${NC}"
    fi
    
    echo "AWS_S3_BUCKET=$BUCKET_NAME" >> .env.aws
}

# Function to create RDS instance
create_rds_instance() {
    echo "🗄️  Setting up RDS PostgreSQL instance"
    
    DB_INSTANCE_ID="roomies-db"
    DB_NAME="roomies_production"
    MASTER_USERNAME="roomiesadmin"
    MASTER_PASSWORD=$(openssl rand -base64 12)
    
    echo "Creating RDS instance (this may take 5-10 minutes)..."
    
    aws rds create-db-instance \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --db-instance-class db.t3.micro \
        --engine postgres \
        --engine-version 14.9 \
        --allocated-storage 20 \
        --storage-type gp2 \
        --db-name "$DB_NAME" \
        --master-username "$MASTER_USERNAME" \
        --master-user-password "$MASTER_PASSWORD" \
        --vpc-security-group-ids "$(aws ec2 describe-security-groups --group-names default --query 'SecurityGroups[0].GroupId' --output text)" \
        --backup-retention-period 7 \
        --no-publicly-accessible \
        --storage-encrypted \
        --skip-final-snapshot 2>/dev/null || echo -e "${YELLOW}⚠️  RDS instance may already exist${NC}"
    
    echo "AWS_RDS_HOST=(will be available after creation)" >> .env.aws
    echo "AWS_RDS_DATABASE=$DB_NAME" >> .env.aws
    echo "AWS_RDS_USERNAME=$MASTER_USERNAME" >> .env.aws
    echo "AWS_RDS_PASSWORD=$MASTER_PASSWORD" >> .env.aws
    
    echo -e "${GREEN}✅ RDS instance creation initiated${NC}"
    echo -e "${YELLOW}Note: Save this password securely: $MASTER_PASSWORD${NC}"
}

# Function to create ElastiCache cluster
create_elasticache() {
    echo "💾 Setting up ElastiCache Redis cluster"
    
    CACHE_CLUSTER_ID="roomies-cache"
    
    aws elasticache create-cache-cluster \
        --cache-cluster-id "$CACHE_CLUSTER_ID" \
        --cache-node-type cache.t3.micro \
        --engine redis \
        --engine-version 6.2 \
        --num-cache-nodes 1 \
        --cache-subnet-group-name default \
        --security-group-ids "$(aws ec2 describe-security-groups --group-names default --query 'SecurityGroups[0].GroupId' --output text)" 2>/dev/null || echo -e "${YELLOW}⚠️  ElastiCache cluster may already exist${NC}"
    
    echo "AWS_ELASTICACHE_HOST=(will be available after creation)" >> .env.aws
    echo "AWS_ELASTICACHE_PORT=6379" >> .env.aws
    
    echo -e "${GREEN}✅ ElastiCache cluster creation initiated${NC}"
}

# Function to create Cognito User Pool
create_cognito() {
    echo "🔐 Setting up Cognito User Pool"
    
    USER_POOL_NAME="roomies-users"
    
    # Create user pool
    USER_POOL_ID=$(aws cognito-idp create-user-pool \
        --pool-name "$USER_POOL_NAME" \
        --auto-verified-attributes email \
        --username-attributes email \
        --mfa-configuration OFF \
        --password-policy "MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true" \
        --query 'UserPool.Id' \
        --output text 2>/dev/null) || echo -e "${YELLOW}⚠️  User pool may already exist${NC}"
    
    if [ ! -z "$USER_POOL_ID" ]; then
        # Create app client
        CLIENT_ID=$(aws cognito-idp create-user-pool-client \
            --user-pool-id "$USER_POOL_ID" \
            --client-name "roomies-app" \
            --generate-secret \
            --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
            --query 'UserPoolClient.ClientId' \
            --output text)
        
        echo "AWS_COGNITO_USER_POOL_ID=$USER_POOL_ID" >> .env.aws
        echo "AWS_COGNITO_CLIENT_ID=$CLIENT_ID" >> .env.aws
        
        echo -e "${GREEN}✅ Cognito User Pool created${NC}"
    fi
}

# Function to verify SES email
setup_ses() {
    echo "📧 Setting up SES for email"
    
    read -p "Enter your email address for SES verification: " EMAIL
    
    aws ses verify-email-identity --email-address "$EMAIL"
    
    echo "AWS_SES_FROM_EMAIL=$EMAIL" >> .env.aws
    
    echo -e "${YELLOW}⚠️  Please check your email and verify the address with AWS SES${NC}"
    echo -e "${GREEN}✅ SES setup initiated${NC}"
}

# Function to create IAM user for the application
create_iam_user() {
    echo "👤 Creating IAM user for Roomies app"
    
    IAM_USER="roomies-backend-user"
    
    # Create user
    aws iam create-user --user-name "$IAM_USER" 2>/dev/null || echo -e "${YELLOW}⚠️  IAM user may already exist${NC}"
    
    # Attach policies
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonRDSDataFullAccess
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonCognitoPowerUser
    aws iam attach-user-policy --user-name "$IAM_USER" --policy-arn arn:aws:iam::aws:policy/AmazonSESFullAccess
    
    # Create access key
    ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$IAM_USER" --output json 2>/dev/null)
    
    if [ ! -z "$ACCESS_KEY_OUTPUT" ]; then
        ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"AccessKeyId": "[^"]*' | cut -d'"' -f4)
        SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | grep -o '"SecretAccessKey": "[^"]*' | cut -d'"' -f4)
        
        echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY_ID" >> .env.aws
        echo "AWS_SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY" >> .env.aws
        
        echo -e "${GREEN}✅ IAM user created with access keys${NC}"
    fi
}

# Main setup flow
echo "Starting AWS services setup..."
echo ""

# Create .env.aws file
echo "# AWS Configuration for Roomies" > .env.aws
echo "AWS_ENABLED=true" >> .env.aws
echo "AWS_REGION=$AWS_REGION" >> .env.aws

# Run setup functions
create_iam_user
create_s3_bucket
create_rds_instance
create_elasticache
create_cognito
setup_ses

echo ""
echo "======================================"
echo -e "${GREEN}✅ AWS Setup Complete!${NC}"
echo "======================================"
echo ""
echo "📝 Next Steps:"
echo "1. Wait for RDS and ElastiCache instances to be available (5-10 minutes)"
echo "2. Get the endpoint URLs:"
echo "   - RDS: aws rds describe-db-instances --db-instance-identifier roomies-db --query 'DBInstances[0].Endpoint.Address' --output text"
echo "   - ElastiCache: aws elasticache describe-cache-clusters --cache-cluster-id roomies-cache --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text"
echo "3. Update the .env.aws file with the endpoint URLs"
echo "4. Copy the contents of .env.aws to your .env file"
echo "5. Run: npm install"
echo "6. Run: npm run dev"
echo ""
echo "⚠️  Important: Keep your .env.aws file secure and never commit it to git!"
