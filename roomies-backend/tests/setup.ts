import 'reflect-metadata';
import { DataSource } from 'typeorm';
import dotenv from 'dotenv';

// Load test environment variables
dotenv.config({ path: '.env.test' });

// Test database connection
export let testDataSource: DataSource;

// Global test setup
beforeAll(async () => {
  // Set test environment
  process.env.NODE_ENV = 'test';
  
  // Mock external services
  jest.setTimeout(10000);
});

afterAll(async () => {
  // Clean up connections
  if (testDataSource && testDataSource.isInitialized) {
    await testDataSource.destroy();
  }
});

// Helper functions for tests
export const testHelpers = {
  // Create test user data
  createTestUser() {
    return {
      email: `test-${Date.now()}@example.com`,
      password: 'TestPassword123!',
      name: 'Test User'
    };
  },

  // Create test household data
  createTestHousehold() {
    return {
      name: `Test Household ${Date.now()}`,
      description: 'A test household for automated testing'
    };
  },

  // Create test task data
  createTestTask() {
    return {
      title: `Test Task ${Date.now()}`,
      description: 'A test task for automated testing',
      pointValue: 10,
      difficulty: 'medium' as const,
      isPrivate: false
    };
  },

  // Generate JWT token for testing
  generateTestJWT(payload: any) {
    // This would use the actual JWT utility
    return 'test-jwt-token';
  },

  // Mock request object
  createMockRequest(overrides: any = {}) {
    return {
      body: {},
      params: {},
      query: {},
      headers: {},
      user: null,
      userId: null,
      householdId: null,
      ...overrides
    };
  },

  // Mock response object
  createMockResponse() {
    const res: any = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      cookie: jest.fn().mockReturnThis(),
      clearCookie: jest.fn().mockReturnThis()
    };
    return res;
  },

  // Mock next function
  createMockNext() {
    return jest.fn();
  },

  // Wait for async operations
  async waitFor(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
};

// Mock implementations for external services
jest.mock('@/services/CloudKitService', () => ({
  __esModule: true,
  default: class MockCloudKitService {
    static getInstance() { return new MockCloudKitService(); }
    getCloudKitStatus() { return { enabled: false, available: false, lastSync: null, error: 'CloudKit disabled' }; }
    syncHousehold = jest.fn().mockResolvedValue(true);
    syncUser = jest.fn().mockResolvedValue(true);
    syncTask = jest.fn().mockResolvedValue(true);
    syncActivity = jest.fn().mockResolvedValue(true);
    syncUserMembership = jest.fn().mockResolvedValue(true);
    joinHouseholdFromCloud = jest.fn().mockResolvedValue(null);
    fetchHouseholdUpdates = jest.fn().mockResolvedValue(true);
  }
}));

jest.mock('@/services/FileStorageService', () => ({
  FileStorageService: jest.fn().mockImplementation(() => ({
    uploadFile: jest.fn().mockResolvedValue({ url: '/uploads/test.jpg' }),
    deleteFile: jest.fn().mockResolvedValue(true)
  }))
}));
