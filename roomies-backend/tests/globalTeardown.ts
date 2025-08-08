// Global teardown for all tests
export default async function globalTeardown() {
  console.log('🧹 Cleaning up global test environment...');

  // Clean up any global resources
  // Database connections, Redis connections, etc.
  
  console.log('✅ Global test environment cleanup complete');
}
