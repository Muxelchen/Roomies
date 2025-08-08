import AWS from 'aws-sdk';
import { logger } from '@/utils/logger';

/**
 * AWS Services Configuration
 * Centralizes all AWS service configurations for the Roomies backend
 */

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
});

// S3 Configuration
export const s3Config = {
  bucket: process.env.AWS_S3_BUCKET || 'roomies-storage',
  region: process.env.AWS_REGION || 'us-east-1',
  signedUrlExpiry: 3600 // 1 hour
};

// RDS Configuration
export const rdsConfig = {
  host: process.env.AWS_RDS_HOST || process.env.DATABASE_HOST || 'localhost',
  port: parseInt(process.env.AWS_RDS_PORT || process.env.DATABASE_PORT || '5432'),
  database: process.env.AWS_RDS_DATABASE || 'roomies_production',
  username: process.env.AWS_RDS_USERNAME || process.env.DATABASE_USER || 'postgres',
  password: process.env.AWS_RDS_PASSWORD || process.env.DATABASE_PASSWORD || '',
  ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : undefined
};

// ElastiCache Configuration
export const elastiCacheConfig = {
  host: process.env.AWS_ELASTICACHE_HOST || process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.AWS_ELASTICACHE_PORT || process.env.REDIS_PORT || '6379'),
  password: process.env.AWS_ELASTICACHE_PASSWORD,
  tls: process.env.NODE_ENV === 'production' ? {} : undefined
};

// Cognito Configuration
export const cognitoConfig = {
  userPoolId: process.env.AWS_COGNITO_USER_POOL_ID || '',
  clientId: process.env.AWS_COGNITO_CLIENT_ID || '',
  region: process.env.AWS_REGION || 'us-east-1',
  identityPoolId: process.env.AWS_COGNITO_IDENTITY_POOL_ID || ''
};

// SES Configuration
export const sesConfig = {
  region: process.env.AWS_REGION || 'us-east-1',
  fromEmail: process.env.AWS_SES_FROM_EMAIL || 'noreply@roomies.app',
  configurationSet: process.env.AWS_SES_CONFIGURATION_SET
};

// CloudWatch Configuration
export const cloudWatchConfig = {
  logGroupName: process.env.AWS_CLOUDWATCH_LOG_GROUP || '/aws/roomies/backend',
  logStreamName: process.env.AWS_CLOUDWATCH_LOG_STREAM || `roomies-${process.env.NODE_ENV}`,
  region: process.env.AWS_REGION || 'us-east-1'
};

// Initialize AWS Services
export const s3 = new AWS.S3();
export const ses = new AWS.SES({ region: sesConfig.region });
export const cognito = new AWS.CognitoIdentityServiceProvider({ region: cognitoConfig.region });
export const cloudWatch = new AWS.CloudWatchLogs({ region: cloudWatchConfig.region });

// Validate AWS Configuration
export const validateAWSConfig = (): boolean => {
  // For local/dev environments, allow the AWS SDK default credential provider chain
  // (e.g., credentials from ~/.aws/credentials, SSO, instance roles) so we don't
  // require static env keys. We only require a region.
  const requiredEnvVars = ['AWS_REGION'];

  const missingVars = requiredEnvVars.filter(varName => !process.env[varName]);

  if (missingVars.length > 0) {
    logger.warn(`⚠️ Missing AWS configuration: ${missingVars.join(', ')}`);
    logger.info('Running in local mode without AWS services');
    return false;
  }

  // Informational: let logs show how credentials will be resolved when explicit keys are absent
  if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
    logger.info('Using AWS default credential provider chain (no static env keys set)');
  }

  logger.info('✅ AWS configuration validated successfully');
  return true;
};

// Check if AWS services are enabled
export const isAWSEnabled = (): boolean => {
  return process.env.AWS_ENABLED === 'true' && validateAWSConfig();
};

export default {
  s3,
  ses,
  cognito,
  cloudWatch,
  s3Config,
  rdsConfig,
  elastiCacheConfig,
  cognitoConfig,
  sesConfig,
  cloudWatchConfig,
  isAWSEnabled,
  validateAWSConfig
};
