module.exports = {
  // Use ts-jest preset to handle TypeScript seamlessly
  preset: 'ts-jest',

  // Test environment
  testEnvironment: 'node',
  
  // Root directory for tests
  roots: ['<rootDir>/src', '<rootDir>/tests'],
  
  // Test patterns
  testMatch: [
    '**/__tests__/**/*.test.{js,ts}',
    '**/?(*.)+(spec|test).{js,ts}'
  ],
  
  // Transform TypeScript files with ts-jest
  transform: {
    '^.+\\.ts$': 'ts-jest'
  },

  // ts-jest configuration
  globals: {
    'ts-jest': {
      tsconfig: '<rootDir>/tsconfig.json'
    }
  },
  
  // Module name mapping for path aliases
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/src/$1'
  },
  
  // Setup files
  setupFilesAfterEnv: ['<rootDir>/tests/setup.ts'],
  
  // Coverage configuration
  collectCoverage: true,
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html', 'json'],
  coveragePathIgnorePatterns: [
    '/node_modules/',
    '/dist/',
    '/coverage/',
    '/tests/',
    '/__tests__/',
    '.d.ts',
    '<rootDir>/src/models/',
    '<rootDir>/src/middleware/security.ts',
    '<rootDir>/src/middleware/cache.ts',
    '<rootDir>/src/middleware/validation.ts',
    '<rootDir>/src/services/EventBroker.ts',
    '<rootDir>/src/routes/events.routes.ts',
    '<rootDir>/src/routes/gamification.routes.ts',
    '<rootDir>/src/routes/notification.routes.ts'
  ],
  
  // Coverage thresholds (start low, increase over time)
  coverageThreshold: {
    global: {
      branches: 28,
      functions: 30,
      lines: 30,
      statements: 30
    },
    // Critical paths should have higher coverage
    './src/controllers/AuthController.ts': {
      branches: 60,
      functions: 60,
      lines: 60,
      statements: 60
    },
    './src/middleware/errorHandler.ts': {
      branches: 50,
      functions: 60,
      lines: 60,
      statements: 60
    }
  },
  
  // Test timeout
  testTimeout: 10000,
  
  // Verbose output
  verbose: true,
  
  // Clear mocks between tests
  clearMocks: true,
  
  // Reset modules between tests
  resetModules: true,
  
  // Detect open handles
  detectOpenHandles: true,
  
  // Force exit after tests
  forceExit: true,
  
  // Maximum worker processes
  maxWorkers: '50%',
  
  // Global setup and teardown
  globalSetup: '<rootDir>/tests/globalSetup.ts',
  globalTeardown: '<rootDir>/tests/globalTeardown.ts'
};
