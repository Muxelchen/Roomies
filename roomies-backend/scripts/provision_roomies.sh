#!/usr/bin/env bash
set -euo pipefail

echo "== Roomies AWS Provisioning (eu-central-1) =="

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)
: "${REGION:?AWS region must be configured (aws configure get region)}"

ENV_OUT="/Users/Max/Roomies/roomies-backend/.env.aws"

S3_BUCKET="roomies-storage-${ACCOUNT_ID}"
DB_INSTANCE_ID="roomies-db"
DB_NAME="roomies_production"
DB_USER="roomiesadmin"
DB_PASS=$(openssl rand -base64 32 | tr -d "\n" | head -c 32)
CACHE_CLUSTER_ID="roomies-cache"
USER_POOL_NAME="roomies-users"
SES_FROM="max.bock.2004@gmail.com"

# S3
if ! aws s3api head-bucket --bucket "$S3_BUCKET" 2>/dev/null; then
  echo "Creating S3 bucket: $S3_BUCKET"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "$S3_BUCKET"
  else
    aws s3api create-bucket --bucket "$S3_BUCKET" --create-bucket-configuration LocationConstraint="$REGION"
  fi
  aws s3api put-bucket-versioning --bucket "$S3_BUCKET" --versioning-configuration Status=Enabled
  CORS_FILE=$(mktemp)
  cat > "$CORS_FILE" <<'JSON'
{
  "CORSRules": [
    {
      "AllowedHeaders": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
      "AllowedOrigins": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
JSON
  aws s3api put-bucket-cors --bucket "$S3_BUCKET" --cors-configuration file://"$CORS_FILE"
  rm -f "$CORS_FILE"
else
  echo "S3 bucket already exists: $S3_BUCKET"
fi

# Security group (best-effort)
SG_ID=$(aws ec2 describe-security-groups --group-names default --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || true)

# RDS (publicly accessible)
if ! aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" >/dev/null 2>&1; then
  echo "Creating RDS instance: $DB_INSTANCE_ID"
  aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine postgres \
    --engine-version 14.9 \
    --allocated-storage 20 \
    --storage-type gp2 \
    --db-name "$DB_NAME" \
    --master-username "$DB_USER" \
    --master-user-password "$DB_PASS" \
    ${SG_ID:+--vpc-security-group-ids "$SG_ID"} \
    --backup-retention-period 7 \
    --publicly-accessible \
    --storage-encrypted \
    --skip-final-snapshot
else
  echo "RDS instance already exists: $DB_INSTANCE_ID"
fi

echo "Waiting for RDS to become available (this can take ~5-10 minutes)..."
aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_ID"
RDS_HOST=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --query 'DBInstances[0].Endpoint.Address' --output text)
RDS_PORT=$(aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_ID" --query 'DBInstances[0].Endpoint.Port' --output text)

# ElastiCache Redis
if ! aws elasticache describe-cache-clusters --cache-cluster-id "$CACHE_CLUSTER_ID" --show-cache-node-info >/dev/null 2>&1; then
  echo "Creating ElastiCache cluster: $CACHE_CLUSTER_ID (best-effort)"
  aws elasticache create-cache-cluster \
    --cache-cluster-id "$CACHE_CLUSTER_ID" \
    --cache-node-type cache.t3.micro \
    --engine redis \
    --engine-version 6.2 \
    --num-cache-nodes 1 \
    --cache-subnet-group-name default \
    ${SG_ID:+--security-group-ids "$SG_ID"} || true
else
  echo "ElastiCache cluster already exists: $CACHE_CLUSTER_ID"
fi

# Wait best-effort for ElastiCache (may fail if subnet group missing); ignore errors
if aws elasticache wait cache-cluster-available --cache-cluster-id "$CACHE_CLUSTER_ID" 2>/dev/null; then
  REDIS_HOST=$(aws elasticache describe-cache-clusters --cache-cluster-id "$CACHE_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)
  REDIS_PORT=$(aws elasticache describe-cache-clusters --cache-cluster-id "$CACHE_CLUSTER_ID" --show-cache-node-info --query 'CacheClusters[0].CacheNodes[0].Endpoint.Port' --output text)
else
  REDIS_HOST=""
  REDIS_PORT=""
fi

# Cognito
USER_POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name "$USER_POOL_NAME" \
  --auto-verified-attributes email \
  --username-attributes email \
  --mfa-configuration OFF \
  --password-policy "MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true" \
  --query 'UserPool.Id' \
  --output text 2>/dev/null || true)
if [ -z "${USER_POOL_ID}" ]; then
  # try to find an existing pool
  USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 60 --query "UserPools[?Name=='$USER_POOL_NAME'].Id | [0]" --output text 2>/dev/null || true)
fi
if [ -n "${USER_POOL_ID}" ] && [ "$USER_POOL_ID" != "None" ]; then
  CLIENT_ID=$(aws cognito-idp create-user-pool-client \
    --user-pool-id "$USER_POOL_ID" \
    --client-name "roomies-app" \
    --generate-secret \
    --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
    --query 'UserPoolClient.ClientId' \
    --output text)
else
  CLIENT_ID=""
fi

# SES verify email (idempotent)
aws ses verify-email-identity --email-address "$SES_FROM" >/dev/null 2>&1 || true

# Write env file
cat > "$ENV_OUT" <<ENV
# Generated by provision script
AWS_ENABLED=true
AWS_REGION=$REGION
AWS_S3_BUCKET=$S3_BUCKET

# RDS
AWS_RDS_HOST=$RDS_HOST
AWS_RDS_PORT=${RDS_PORT:-5432}
AWS_RDS_DATABASE=$DB_NAME
AWS_RDS_USERNAME=$DB_USER
AWS_RDS_PASSWORD=$DB_PASS

# ElastiCache (may be empty if creation failed; VPC-only)
AWS_ELASTICACHE_HOST=${REDIS_HOST:-}
AWS_ELASTICACHE_PORT=${REDIS_PORT:-}

# Cognito
AWS_COGNITO_USER_POOL_ID=${USER_POOL_ID:-}
AWS_COGNITO_CLIENT_ID=${CLIENT_ID:-}

# SES
AWS_SES_FROM_EMAIL=$SES_FROM
ENV

echo "Wrote $ENV_OUT"

# Output summary
printf "\nSummary:\n"
echo "S3 bucket:       $S3_BUCKET"
echo "RDS endpoint:    $RDS_HOST:${RDS_PORT:-5432}"
echo "ElastiCache host: ${REDIS_HOST:-(not available)}:${REDIS_PORT:-}"
echo "Cognito pool:    ${USER_POOL_ID:-(not available)}"
echo "Cognito client:  ${CLIENT_ID:-(not available)}"
echo "SES from email:  $SES_FROM (verify in console)"

