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
console.log('# CloudKit Configuration');
console.log('CLOUDKIT_ENABLED=false');
console.log('CLOUDKIT_CONTAINER_ID=iCloud.com.yourcompany.roomies');
console.log('# Optional if using CloudKit Web Services');
console.log('CLOUDKIT_API_TOKEN=');
console.log('');
console.log('# IMPORTANT SECURITY NOTES:');
console.log('# 1. Store these secrets in a secure secret manager for your hosting platform');
console.log('# 2. NEVER commit these to version control');
console.log('# 3. Use environment-specific secrets for dev/staging/prod');
console.log('# 4. Rotate secrets regularly (every 90 days)');
console.log('');
console.log('📋 Copy the above values to your .env.production file');
