import { AuthController } from '@/controllers/AuthController';
import { testHelpers } from '../setup';
import { ValidationError, UnauthorizedError, ConflictError } from '@/middleware/errorHandler';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';

// Mock the database connection
jest.mock('@/config/database', () => ({
  AppDataSource: {
    getRepository: jest.fn(),
    isInitialized: true
  }
}));

// Mock JWT utilities
jest.mock('@/utils/jwt', () => ({
  generateToken: jest.fn(() => 'mock-jwt-token'),
  refreshToken: jest.fn(() => 'mock-refreshed-token')
}));

// Mock logger
jest.mock('@/utils/logger', () => ({
  logger: {
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn()
  }
}));

describe('AuthController', () => {
  let authController: AuthController;
  let mockUserRepository: any;
  let mockUser: any;

  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();

    // Create mock user repository
    mockUserRepository = {
      findOne: jest.fn(),
      create: jest.fn(),
      save: jest.fn()
    };

    // Mock AppDataSource.getRepository
    (AppDataSource.getRepository as jest.Mock).mockReturnValue(mockUserRepository);

    // Create mock user
    mockUser = {
      id: 'test-user-id',
      email: 'test@example.com',
      name: 'Test User',
      hashedPassword: 'hashed-password',
      avatarColor: 'blue',
      points: 0,
      level: 1,
      streakDays: 0,
      createdAt: new Date(),
      lastActivity: new Date(),
      validatePassword: jest.fn(),
      getTotalTasksCompleted: jest.fn(() => 0),
      householdMemberships: []
    };

    authController = new AuthController();
  });

  describe('register', () => {
    it('should successfully register a new user with valid data', async () => {
      const testUserData = testHelpers.createTestUser();
      const req = testHelpers.createMockRequest({
        body: testUserData
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock that user doesn't exist
      mockUserRepository.findOne.mockResolvedValue(null);
      
      // Mock user creation
      const createdUser = { ...mockUser, ...testUserData };
      mockUserRepository.create.mockReturnValue(createdUser);
      mockUserRepository.save.mockResolvedValue(createdUser);
      
      // Mock validation (no errors)
      const mockValidate = jest.fn().mockResolvedValue([]);
      jest.doMock('class-validator', () => ({
        validate: mockValidate
      }));

      await authController.register(req, res, next);

      // Verify response
      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              id: createdUser.id,
              email: createdUser.email,
              name: createdUser.name
            }),
            token: 'mock-jwt-token'
          }),
          message: 'User registered successfully'
        })
      );

      // Verify repository calls
      expect(mockUserRepository.findOne).toHaveBeenCalledWith({
        where: { email: testUserData.email.toLowerCase() }
      });
      expect(mockUserRepository.create).toHaveBeenCalled();
      expect(mockUserRepository.save).toHaveBeenCalled();
    });

    it('should throw ValidationError for missing required fields', async () => {
      const req = testHelpers.createMockRequest({
        body: { email: 'test@example.com' } // Missing password and name
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.register(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw ValidationError for invalid email format', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'invalid-email',
          password: 'TestPassword123!',
          name: 'Test User'
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.register(req, res, next);
expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw ValidationError for weak password', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'test@example.com',
          password: '123', // Too short
          name: 'Test User'
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();
      await authController.register(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw ValidationError for invalid name', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'test@example.com',
          password: 'TestPassword123!',
          name: 'X' // Too short
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();
      await authController.register(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw ConflictError when user already exists', async () => {
      const testUserData = testHelpers.createTestUser();
      const req = testHelpers.createMockRequest({
        body: testUserData
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock that user already exists
      mockUserRepository.findOne.mockResolvedValue(mockUser);

      await authController.register(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ConflictError));
    });
  });

  describe('login', () => {
    it('should successfully login with valid credentials', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'test@example.com',
          password: 'TestPassword123!'
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock user found
      mockUserRepository.findOne.mockResolvedValue(mockUser);
      
      // Mock successful password validation
      mockUser.validatePassword.mockResolvedValue(true);
      
      // Mock saving updated user
      mockUserRepository.save.mockResolvedValue(mockUser);

      await authController.login(req, res, next);

      // Verify response
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              id: mockUser.id,
              email: mockUser.email,
              name: mockUser.name
            }),
            token: 'mock-jwt-token'
          }),
          message: 'Login successful'
        })
      );

      // Verify password validation was called
      expect(mockUser.validatePassword).toHaveBeenCalledWith('TestPassword123!');
      
      // Verify last activity was updated
      expect(mockUserRepository.save).toHaveBeenCalled();
    });

    it('should throw ValidationError for missing credentials', async () => {
      const req = testHelpers.createMockRequest({
        body: { email: 'test@example.com' } // Missing password
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.login(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw UnauthorizedError for non-existent user', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'nonexistent@example.com',
          password: 'TestPassword123!'
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock user not found
      mockUserRepository.findOne.mockResolvedValue(null);

      await authController.login(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should throw UnauthorizedError for invalid password', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          email: 'test@example.com',
          password: 'WrongPassword!'
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock user found
      mockUserRepository.findOne.mockResolvedValue(mockUser);
      mockUser.validatePassword.mockResolvedValue(false);

      await authController.login(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });
  });

  describe('getCurrentUser', () => {
    it('should return current user data for authenticated user', async () => {
      const req = testHelpers.createMockRequest({
        user: mockUser,
        userId: mockUser.id
      });
      const res = testHelpers.createMockResponse();

      // Mock user found with relations
      mockUserRepository.findOne.mockResolvedValue({
        ...mockUser,
        badges: [],
        rewardRedemptions: []
      });

      const next = testHelpers.createMockNext();
      await authController.getCurrentUser(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            id: mockUser.id,
            email: mockUser.email,
            name: mockUser.name
          })
        })
      );
    });

    it('should throw UnauthorizedError for unauthenticated request', async () => {
      const req = testHelpers.createMockRequest({
        user: null
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.getCurrentUser(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });
  });

  describe('changePassword', () => {
    it('should successfully change password with valid data', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          currentPassword: 'OldPassword123!',
          newPassword: 'NewPassword123!'
        },
        user: mockUser,
        userId: mockUser.id
      });
      const res = testHelpers.createMockResponse();

      // Mock successful current password validation
      mockUser.validatePassword.mockResolvedValue(true);
      mockUserRepository.save.mockResolvedValue(mockUser);
      const next = testHelpers.createMockNext();

      await authController.changePassword(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Password changed successfully'
        })
      );

      expect(mockUser.validatePassword).toHaveBeenCalledWith('OldPassword123!');
      expect(mockUserRepository.save).toHaveBeenCalledWith(mockUser);
    });

    it('should throw ValidationError for missing fields', async () => {
      const req = testHelpers.createMockRequest({
        body: { currentPassword: 'OldPassword123!' }, // Missing newPassword
        user: mockUser
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.changePassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw UnauthorizedError for unauthenticated user', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          currentPassword: 'OldPassword123!',
          newPassword: 'NewPassword123!'
        },
        user: null
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.changePassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should throw UnauthorizedError for incorrect current password', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          currentPassword: 'WrongPassword!',
          newPassword: 'NewPassword123!'
        },
        user: mockUser,
        userId: mockUser.id
      });
      const res = testHelpers.createMockResponse();

      // Mock failed current password validation
      mockUser.validatePassword.mockResolvedValue(false);

      const next = testHelpers.createMockNext();
      await authController.changePassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should throw ValidationError for weak new password', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          currentPassword: 'OldPassword123!',
          newPassword: '123' // Too weak
        },
        user: mockUser,
        userId: mockUser.id
      });
      const res = testHelpers.createMockResponse();

      mockUser.validatePassword.mockResolvedValue(true);

      const next = testHelpers.createMockNext();
      await authController.changePassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });

  describe('logout', () => {
    it('should successfully logout authenticated user', async () => {
      const req = testHelpers.createMockRequest({
        userId: mockUser.id
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.logout(req, res, next);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Logged out successfully'
        })
      );
    });
  });

  describe('refreshToken', () => {
    it('should successfully refresh valid token', async () => {
      const { refreshToken } = require('@/utils/jwt');
      refreshToken.mockReturnValue('new-jwt-token');

      const req = testHelpers.createMockRequest({
        body: { refreshToken: 'valid-refresh-token' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.refreshToken(req, res, next);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            token: 'new-jwt-token'
          }),
          message: 'Token refreshed successfully'
        })
      );
    });

    it('should throw ValidationError for missing refresh token', async () => {
      const req = testHelpers.createMockRequest({
        body: {} // Missing refreshToken
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.refreshToken(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw UnauthorizedError for invalid refresh token', async () => {
      const { refreshToken } = require('@/utils/jwt');
      refreshToken.mockReturnValue(null); // Invalid token

      const req = testHelpers.createMockRequest({
        body: { refreshToken: 'invalid-refresh-token' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.refreshToken(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });
  });
});
