import { AuthController } from '@/controllers/AuthController';
import TokenService from '@/services/TokenService';
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

  describe('forgotPassword', () => {
    it('should request password reset without leaking existence', async () => {
      const req = testHelpers.createMockRequest({
        body: { email: 'test@example.com' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // User exists
      mockUserRepository.findOne.mockResolvedValue(mockUser);
      mockUserRepository.save.mockResolvedValue(mockUser);

      await authController.forgotPassword(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({ success: true })
      );
      expect(mockUserRepository.save).toHaveBeenCalled();
    });

    it('should validate email presence', async () => {
      const req = testHelpers.createMockRequest({ body: {} });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.forgotPassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });

  describe('resetPassword', () => {
    it('should reset password with valid token', async () => {
      const rawToken = 'reset-token';
      const userWithReset = { ...mockUser } as any;
      userWithReset.passwordResetTokenHash = TokenService.hashToken(rawToken);
      userWithReset.passwordResetExpires = new Date(Date.now() + 60_000);
      mockUserRepository.findOne.mockResolvedValue(userWithReset);
      mockUserRepository.save.mockResolvedValue(userWithReset);

      const req = testHelpers.createMockRequest({
        body: { token: rawToken, newPassword: 'NewPassword123!', email: 'test@example.com' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.resetPassword(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
      expect(mockUserRepository.save).toHaveBeenCalled();
    });

    it('should reject expired token', async () => {
      const rawToken = 'expired-token';
      const userWithReset = { ...mockUser } as any;
      userWithReset.passwordResetTokenHash = TokenService.hashToken(rawToken);
      userWithReset.passwordResetExpires = new Date(Date.now() - 60_000);
      mockUserRepository.findOne.mockResolvedValue(userWithReset);

      const req = testHelpers.createMockRequest({
        body: { token: rawToken, newPassword: 'NewPassword123!', email: 'test@example.com' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.resetPassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should validate required fields', async () => {
      const req = testHelpers.createMockRequest({ body: {} });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.resetPassword(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });

  describe('verifyEmail and verifyEmailLink', () => {
    it('should verify email with valid token', async () => {
      const rawToken = 'verify-token';
      const userWithVerification = { ...mockUser } as any;
      userWithVerification.emailVerificationTokenHash = TokenService.hashToken(rawToken);
      userWithVerification.emailVerificationExpires = new Date(Date.now() + 60_000);
      userWithVerification.emailVerified = false;
      mockUserRepository.findOne.mockResolvedValue(userWithVerification);
      mockUserRepository.save.mockResolvedValue(userWithVerification);

      const req = testHelpers.createMockRequest({
        body: { token: rawToken, email: 'test@example.com' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.verifyEmail(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
    });

    it('should verify via link with query params', async () => {
      const rawToken = 'verify-token';
      const userWithVerification = { ...mockUser } as any;
      userWithVerification.emailVerificationTokenHash = TokenService.hashToken(rawToken);
      userWithVerification.emailVerificationExpires = new Date(Date.now() + 60_000);
      userWithVerification.emailVerified = false;
      mockUserRepository.findOne.mockResolvedValue(userWithVerification);
      mockUserRepository.save.mockResolvedValue(userWithVerification);

      const req = testHelpers.createMockRequest({
        query: { token: rawToken, email: 'test@example.com' }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.verifyEmailLink(req as any, res, next);
      expect(res.send).toHaveBeenCalledWith(expect.stringContaining('Email verified'));
    });

    it('should handle invalid link parameters', async () => {
      const req = testHelpers.createMockRequest({ query: {} });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.verifyEmailLink(req as any, res, next);
      expect(res.status).toHaveBeenCalledWith(400);
    });
  });

  describe('appleSignIn - error paths', () => {
    it('should validate missing identityToken', async () => {
      const req = testHelpers.createMockRequest({ body: {} });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.appleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should reject when jwt.decode returns no kid', async () => {
      jest.resetModules();
      const jwt = require('jsonwebtoken');
      jest.spyOn(jwt, 'decode').mockReturnValue({ header: {} });

      const req = testHelpers.createMockRequest({ body: { identityToken: 'abc' } });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.appleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should reject when JWK not found', async () => {
      const jwt = require('jsonwebtoken');
      jest.spyOn(jwt, 'decode').mockReturnValue({ header: { kid: 'kid1', alg: 'RS256' } });

      // Force fetchAppleJWKs to return no matching key
      jest.spyOn(authController as any, 'fetchAppleJWKs').mockResolvedValue({ keys: [] });

      const req = testHelpers.createMockRequest({ body: { identityToken: 'abc' } });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.appleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should handle key conversion failure', async () => {
      const jwt = require('jsonwebtoken');
      jest.spyOn(jwt, 'decode').mockReturnValue({ header: { kid: 'kid1', alg: 'RS256' } });
      jest.spyOn(authController as any, 'fetchAppleJWKs').mockResolvedValue({ keys: [{ kid: 'kid1', kty: 'RSA' }] });

      const req = testHelpers.createMockRequest({ body: { identityToken: 'abc' } });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.appleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should handle verification failure', async () => {
      const jwt = require('jsonwebtoken');
      jest.spyOn(jwt, 'decode').mockReturnValue({ header: { kid: 'kid1', alg: 'RS256' } });
      jest.spyOn(authController as any, 'fetchAppleJWKs').mockResolvedValue({ keys: [{ kid: 'kid1', kty: 'RSA' }] });

      // Mock crypto.createPublicKey to bypass conversion
      const crypto = require('crypto');
      jest.spyOn(crypto, 'createPublicKey').mockReturnValue({ export: () => 'pem' } as any);

      // Force verify to throw
      jest.spyOn(jwt, 'verify').mockImplementation(() => { throw new Error('invalid'); });

      const req = testHelpers.createMockRequest({ body: { identityToken: 'abc' } });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      await authController.appleSignIn(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });
  });

  // Success path for Apple Sign-In is validated in a dedicated isolated test file

  describe('additional branches', () => {
    it('should handle deleteAccount with anonymization and cleanup', async () => {
      const req = testHelpers.createMockRequest({ user: mockUser, userId: mockUser.id });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock repository chaining used in deleteAccount
      const mockQueryBuilder: any = {
        update: jest.fn().mockReturnThis(),
        set: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        execute: jest.fn().mockResolvedValue({})
      };

      (AppDataSource.getRepository as jest.Mock).mockImplementation((entity) => {
        return {
          ...mockUserRepository,
          createQueryBuilder: jest.fn(() => mockQueryBuilder),
          findOne: jest.fn().mockResolvedValue({ ...mockUser })
        };
      });

      await authController.deleteAccount(req, res, next);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
    });

    it('should throw when getCurrentUser cannot find user', async () => {
      const req = testHelpers.createMockRequest({ user: mockUser, userId: 'missing' });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();
      mockUserRepository.findOne.mockResolvedValue(null);
      await authController.getCurrentUser(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });
});
