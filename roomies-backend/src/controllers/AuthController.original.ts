import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { generateToken, refreshToken as refreshJWT } from '@/utils/jwt';
import { logger } from '@/utils/logger';
import { 
  ValidationError, 
  UnauthorizedError, 
  ConflictError, 
  createResponse,
  createErrorResponse,
  asyncHandler
} from '@/middleware/errorHandler';
import { validate } from 'class-validator';

export class AuthController {
  private userRepository = AppDataSource.getRepository(User);

  /**
   * Register a new user
   */
  async register(req: Request, res: Response): Promise<void> {
    const { email, password, name } = req.body;

    // Validate input
    if (!email || !password || !name) {
      res.status(400).json(createErrorResponse(
        'Email, password, and name are required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    // Check if user already exists
    const existingUser = await this.userRepository.findOne({
      where: { email: email.toLowerCase() }
    });

    if (existingUser) {
      res.status(409).json(createErrorResponse(
        'User with this email already exists',
        'USER_EXISTS'
      ));
      return;
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      res.status(400).json(createErrorResponse(
        'Invalid email format',
        'INVALID_EMAIL'
      ));
      return;
    }

    // Validate password strength
    if (password.length < 8) {
      res.status(400).json(createErrorResponse(
        'Password must be at least 8 characters long',
        'WEAK_PASSWORD'
      ));
      return;
    }

    // Validate name
    if (name.trim().length < 2) {
      res.status(400).json(createErrorResponse(
        'Name must be at least 2 characters long',
        'INVALID_NAME'
      ));
      return;
    }

    try {
      // Create new user
      const user = this.userRepository.create({
        email: email.toLowerCase().trim(),
        name: name.trim(),
        hashedPassword: password, // Will be hashed by the entity
        avatarColor: ['blue', 'green', 'orange', 'purple', 'red', 'teal', 'pink']
          [Math.floor(Math.random() * 7)],
        points: 0,
        streakDays: 0
      });

      // Validate entity
      const errors = await validate(user);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      // Save user
      await this.userRepository.save(user);

      // Generate JWT token
      const token = generateToken({
        userId: user.id,
        email: user.email,
        householdId: undefined // New users don't have household initially
      });

      logger.info('User registered successfully', { userId: user.id, email: user.email });

      // Return user data and token
      res.status(201).json(createResponse({
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          avatarColor: user.avatarColor,
          points: user.points,
          level: user.level,
          streakDays: user.streakDays,
          createdAt: user.createdAt
        },
        token
      }, 'User registered successfully'));

    } catch (error) {
      logger.error('User registration failed:', error);
      res.status(500).json(createErrorResponse(
        'Registration failed',
        'REGISTRATION_ERROR'
      ));
    }
  }

  /**
   * Login user
   */
  async login(req: Request, res: Response): Promise<void> {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json(createErrorResponse(
        'Email and password are required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      // Find user with household memberships
      const user = await this.userRepository.findOne({
        where: { email: email.toLowerCase() },
        relations: ['householdMemberships', 'householdMemberships.household']
      });

      if (!user) {
        res.status(401).json(createErrorResponse(
          'Invalid email or password',
          'INVALID_CREDENTIALS'
        ));
        return;
      }

      // Validate password
      const isValidPassword = await user.validatePassword(password);
      if (!isValidPassword) {
        res.status(401).json(createErrorResponse(
          'Invalid email or password',
          'INVALID_CREDENTIALS'
        ));
        return;
      }

      // Update last activity
      user.lastActivity = new Date();
      await this.userRepository.save(user);

      // Get current household if user has one
      const activeMembership = user.householdMemberships?.find(m => m.isActive);
      const householdId = activeMembership?.household?.id;

      // Generate JWT token
      const token = generateToken({
        userId: user.id,
        email: user.email,
        householdId,
        role: activeMembership?.role
      });

      logger.info('User logged in successfully', { userId: user.id, email: user.email });

      // Return user data and token
      res.json(createResponse({
        user: {
          id: user.id,
          name: user.name,
          email: user.email,
          avatarColor: user.avatarColor,
          points: user.points,
          level: user.level,
          streakDays: user.streakDays,
          lastActivity: user.lastActivity,
          household: activeMembership ? {
            id: activeMembership.household.id,
            name: activeMembership.household.name,
            role: activeMembership.role
          } : null
        },
        token
      }, 'Login successful'));

    } catch (error) {
      logger.error('User login failed:', error);
      res.status(500).json(createErrorResponse(
        'Login failed',
        'LOGIN_ERROR'
      ));
    }
  }

  /**
   * Refresh JWT token
   */
  async refreshToken(req: Request, res: Response): Promise<void> {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      res.status(400).json(createErrorResponse(
        'Refresh token is required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      const newToken = refreshJWT(refreshToken);
      
      if (!newToken) {
        res.status(401).json(createErrorResponse(
          'Invalid refresh token',
          'INVALID_REFRESH_TOKEN'
        ));
        return;
      }

      res.json(createResponse({
        token: newToken
      }, 'Token refreshed successfully'));

    } catch (error) {
      logger.error('Token refresh failed:', error);
      res.status(401).json(createErrorResponse(
        'Token refresh failed',
        'TOKEN_REFRESH_ERROR'
      ));
    }
  }

  /**
   * Logout user
   */
  async logout(req: Request, res: Response): Promise<void> {
    // In a more sophisticated setup, we would blacklist the token
    // For now, we just acknowledge the logout
    logger.info('User logged out', { userId: req.userId });
    
    res.json(createResponse(
      {},
      'Logged out successfully'
    ));
  }

  /**
   * Get current user profile
   */
  async getCurrentUser(req: Request, res: Response): Promise<void> {
    if (!req.user) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      // Get user with all related data
      const user = await this.userRepository.findOne({
        where: { id: req.userId },
        relations: [
          'householdMemberships',
          'householdMemberships.household',
          'badges',
          'rewardRedemptions'
        ]
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      const activeMembership = user.householdMemberships?.find(m => m.isActive);

      res.json(createResponse({
        id: user.id,
        name: user.name,
        email: user.email,
        avatarColor: user.avatarColor,
        points: user.points,
        level: user.level,
        streakDays: user.streakDays,
        lastActivity: user.lastActivity,
        createdAt: user.createdAt,
        household: activeMembership ? {
          id: activeMembership.household.id,
          name: activeMembership.household.name,
          role: activeMembership.role,
          joinedAt: activeMembership.joinedAt
        } : null,
        badges: user.badges?.length || 0,
        totalRedemptions: user.rewardRedemptions?.length || 0,
        tasksCompleted: user.getTotalTasksCompleted()
      }));

    } catch (error) {
      logger.error('Get current user failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get user profile',
        'GET_USER_ERROR'
      ));
    }
  }

  /**
   * Forgot password (placeholder for email integration)
   */
  async forgotPassword(req: Request, res: Response): Promise<void> {
    const { email } = req.body;

    if (!email) {
      res.status(400).json(createErrorResponse(
        'Email is required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    // TODO: Implement email integration when available
    logger.info('Password reset requested', { email });

    // Always return success for security (don't reveal if email exists)
    res.json(createResponse(
      {},
      'If an account with that email exists, a password reset link has been sent'
    ));
  }

  /**
   * Reset password (placeholder for email integration)
   */
  async resetPassword(req: Request, res: Response): Promise<void> {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      res.status(400).json(createErrorResponse(
        'Token and new password are required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    // TODO: Implement token validation and password reset
    logger.info('Password reset attempted', { token: token.substring(0, 10) + '...' });

    res.status(501).json(createErrorResponse(
      'Password reset not implemented yet',
      'NOT_IMPLEMENTED'
    ));
  }

  /**
   * Change password for authenticated user
   */
  async changePassword(req: Request, res: Response): Promise<void> {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      res.status(400).json(createErrorResponse(
        'Current password and new password are required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    if (!req.user) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      // Validate current password
      const isValidPassword = await req.user.validatePassword(currentPassword);
      if (!isValidPassword) {
        res.status(401).json(createErrorResponse(
          'Current password is incorrect',
          'INVALID_PASSWORD'
        ));
        return;
      }

      // Validate new password
      if (newPassword.length < 8) {
        res.status(400).json(createErrorResponse(
          'New password must be at least 8 characters long',
          'WEAK_PASSWORD'
        ));
        return;
      }

      // Update password
      req.user.hashedPassword = newPassword; // Will be hashed by the entity
      await this.userRepository.save(req.user);

      logger.info('Password changed successfully', { userId: req.userId });

      res.json(createResponse(
        {},
        'Password changed successfully'
      ));

    } catch (error) {
      logger.error('Change password failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to change password',
        'CHANGE_PASSWORD_ERROR'
      ));
    }
  }

  /**
   * Delete user account
   */
  async deleteAccount(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      // TODO: Implement proper account deletion with data cleanup
      // This should:
      // 1. Remove user from all households
      // 2. Transfer or delete user's created content
      // 3. Clean up all related data
      // 4. Potentially keep some data for analytics (anonymized)

      logger.warn('Account deletion requested', { userId: req.userId });

      res.status(501).json(createErrorResponse(
        'Account deletion not fully implemented yet',
        'NOT_IMPLEMENTED'
      ));

    } catch (error) {
      logger.error('Delete account failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to delete account',
        'DELETE_ACCOUNT_ERROR'
      ));
    }
  }
}
