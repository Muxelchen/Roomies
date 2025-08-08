#!/bin/bash

# 🔐 AWS Credentials Setup Script
# This script helps securely set up AWS credentials without exposing them in files

echo "🔐 AWS Credentials Setup for Roomies Backend"
echo "============================================"
echo ""
echo "⚠️  SECURITY WARNING: Never commit credentials to version control!"
echo ""

# Check if running in production
if [ "$NODE_ENV" = "production" ]; then
    echo "📌 Production environment detected. Using IAM role credentials."
    echo "   Ensure your EC2 instance has the proper IAM role attached."
    exit 0
fi

# Function to safely read sensitive input
read_secret() {
    local prompt="$1"
    local var_name="$2"
    echo -n "$prompt"
    read -s value
    echo ""
    export "$var_name"="$value"
}

# Check if credentials are already set
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "✅ AWS credentials already configured in environment."
    echo "   To reconfigure, unset AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY first."
else
    echo "📝 Please enter your AWS credentials:"
    echo ""
    
    # Read AWS credentials
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read_secret "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    
    # Read RDS password
    read_secret "AWS RDS Password: " AWS_RDS_PASSWORD
    
    # Export for current session
    export AWS_ACCESS_KEY_ID
    export AWS_SECRET_ACCESS_KEY
    export AWS_RDS_PASSWORD
    
    echo ""
    echo "✅ Credentials set for current session."
    echo ""
    echo "To make these permanent, add to your shell profile (~/.zshrc or ~/.bash_profile):"
    echo ""
    echo "# Roomies AWS Credentials (Development Only)"
    echo "export AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID'"
    echo "export AWS_SECRET_ACCESS_KEY='[HIDDEN]'"
    echo "export AWS_RDS_PASSWORD='[HIDDEN]'"
    echo ""
    echo "⚠️  For production, use IAM roles or AWS Secrets Manager instead!"
fi

# Verify AWS CLI configuration
echo ""
echo "🔍 Verifying AWS configuration..."
if command -v aws &> /dev/null; then
    aws sts get-caller-identity &> /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ AWS CLI configured and authenticated successfully."
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        echo "   Account ID: $ACCOUNT_ID"
    else
        echo "❌ AWS authentication failed. Please check your credentials."
        exit 1
    fi
else
    echo "⚠️  AWS CLI not installed. Install it for better credential management:"
    echo "   brew install awscli"
fi

echo ""
echo "🎉 Setup complete! You can now start the backend with: npm run dev"
