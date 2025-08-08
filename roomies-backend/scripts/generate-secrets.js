#!/usr/bin/env node

/**
 * 🔐 Secure Secret Generator for Roomies Backend
 * Generates cryptographically secure secrets for JWT and session management
 * 
 * Usage: node scripts/generate-secrets.js
 */

const crypto = require('crypto');

function generateSecureSecret(length = 64) {
  return crypto.randomBytes(length).toString('hex');
}

function generateJWTSecret() {
  // Generate a 256-bit (32 bytes) secret for JWT
  return crypto.randomBytes(32).toString('base64url');
}

function generatePassword(length = 32) {
  // Generate a secure password with mixed characters
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*';
  let password = '';
  for (let i = 0; i < length; i++) {
    password += charset.charAt(Math.floor(Math.random() * charset.length));
  }
  return password;
}

console.log('🔐 Secure Secrets for Roomies Backend Production');
console.log('================================================');
console.log('');
console.log('# JWT Configuration');
console.log(`JWT_SECRET=${generateJWTSecret()}`);
console.log('JWT_EXPIRES_IN=24h');
console.log('');
console.log('# Session Configuration');
console.log(`SESSION_SECRET=${generateSecureSecret(32)}`);
console.log('');
console.log('# Database Passwords');
console.log(`DB_PASSWORD=${generatePassword(24)}`);
console.log(`REDIS_PASSWORD=${generatePassword(24)}`);
console.log('');
console.log('# AWS Configuration (Replace with actual values)');
console.log('AWS_ACCESS_KEY_ID=AKIA...');
console.log('AWS_SECRET_ACCESS_KEY=...');
console.log('');
console.log('# IMPORTANT SECURITY NOTES:');
console.log('# 1. Store these secrets in AWS Secrets Manager or similar');
console.log('# 2. NEVER commit these to version control');
console.log('# 3. Use environment-specific secrets for dev/staging/prod');
console.log('# 4. Rotate secrets regularly (every 90 days)');
console.log('# 5. Use IAM roles instead of access keys when possible');
console.log('');
console.log('📋 Copy the above values to your .env.production file');
