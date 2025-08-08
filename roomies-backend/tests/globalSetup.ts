import dotenv from 'dotenv';

// Global setup for all tests
export default async function globalSetup() {
  console.log('🧪 Setting up global test environment...');

  // Load test environment variables
  dotenv.config({ path: '.env.test' });

  // Set test environment
  process.env.NODE_ENV = 'test';
  
  // Disable external services for testing
  process.env.CLOUDKIT_ENABLED = 'false';
  // No AWS in codebase
  
  // Set test database configuration
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL || 'postgresql://localhost:5432/roomies_test';
  
  // Set up test-specific configuration
  process.env.JWT_SECRET = 'test-jwt-secret-for-testing-only';
  process.env.BCRYPT_ROUNDS = '4'; // Lower rounds for faster tests
  
  // Disable logging during tests
  process.env.LOG_LEVEL = 'error';
  
  console.log('✅ Global test environment setup complete');
}
