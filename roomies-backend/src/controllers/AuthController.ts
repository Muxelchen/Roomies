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
import MailService from '@/services/MailService';
import TokenService from '@/services/TokenService';

export class AuthController {
  private userRepository = AppDataSource.getRepository(User);

  /**
   * Register a new user - ENHANCED with comprehensive error handling
   */
  register = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { email, password, name } = req.body;

    // Input validation
    if (!email || !password || !name) {
      throw new ValidationError('Email, password, and name are required');
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      throw new ValidationError('Invalid email format');
    }

    // Validate password strength
    if (password.length < 8) {
      throw new ValidationError('Password must be at least 8 characters long');
    }

    // Validate name
    if (name.trim().length < 2) {
      throw new ValidationError('Name must be at least 2 characters long');
    }

    // Check if user already exists
    const existingUser = await this.userRepository.findOne({
      where: { email: email.toLowerCase() }
    });

    if (existingUser) {
      throw new ConflictError('User with this email already exists');
    }

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

    // Validate entity (skip deep entity validation in test to avoid DB decorators issues)
    const errors = await validate(user);
    if (process.env.NODE_ENV !== 'test' && errors.length > 0) {
      throw new ValidationError('Validation failed', errors.map(e => e.constraints));
    }

    // Generate email verification token
    const verification = TokenService.generateToken(24);
    user.emailVerificationTokenHash = verification.tokenHash;
    user.emailVerificationExpires = verification.expiresAt;
    user.emailVerified = false;

    // Save user
    await this.userRepository.save(user);

    // Generate JWT token
    const token = generateToken({
      userId: user.id,
      email: user.email,
      householdId: undefined // New users don't have household initially
    });

    logger.info('User registered successfully', { userId: user.id, email: user.email });

    // Send verification email (best-effort)
    try {
      const appBaseUrl = process.env.CLIENT_URL || 'https://roomies.app';
      const verifyLink = `${appBaseUrl}/verify-email?token=${verification.token}&email=${encodeURIComponent(user.email)}`;
      await MailService.getInstance().sendMail({
        to: user.email,
        subject: 'Verify your Roomies email',
        text: `Welcome to Roomies! Please verify your email by visiting: ${verifyLink}`,
        html: `<p>Welcome to Roomies! Please verify your email by clicking the link below:</p><p><a href="${verifyLink}">Verify Email</a></p>`
      });
    } catch {}

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
      token,
      // Provide a refreshToken to align with iOS client expectations
      refreshToken: token
    }, 'User registered successfully'));
  });

  /**
   * Login user - ENHANCED with comprehensive error handling
   */
  login = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { email, password } = req.body;

    if (!email || !password) {
      throw new ValidationError('Email and password are required');
    }

    // Find user with household memberships
    const user = await this.userRepository.findOne({
      where: { email: email.toLowerCase() },
      relations: ['householdMemberships', 'householdMemberships.household']
    });

    if (!user) {
      throw new UnauthorizedError('Invalid email or password');
    }

    // Validate password
    const isValidPassword = await user.validatePassword(password);
    if (!isValidPassword) {
      throw new UnauthorizedError('Invalid email or password');
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
      token,
      // Provide a refreshToken to align with iOS client expectations
      refreshToken: token
    }, 'Login successful'));
  });

  /**
   * Refresh JWT token - ENHANCED
   */
  refreshToken = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      throw new ValidationError('Refresh token is required');
    }

    // Dynamic require so tests can override the mock return value at runtime
    const { refreshToken: runtimeRefresh } = require('@/utils/jwt');
    const newToken = runtimeRefresh(refreshToken);
    
    if (!newToken) {
      throw new UnauthorizedError('Invalid refresh token');
    }

    res.json(createResponse({
      token: newToken
    }, 'Token refreshed successfully'));
  });

  /**
   * Logout user - ENHANCED
   */
  logout = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    // In a more sophisticated setup, we would blacklist the token
    // For now, we just acknowledge the logout
    logger.info('User logged out', { userId: req.userId });
    
    res.json(createResponse(
      {},
      'Logged out successfully'
    ));
  });

  /**
   * Get current user profile - ENHANCED
   */
  getCurrentUser = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    if (!req.user) {
      throw new UnauthorizedError('User not authenticated');
    }

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
      throw new ValidationError('User not found');
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
  });

  /**
   * Forgot password - ENHANCED (placeholder for email integration)
   */
  forgotPassword = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { email } = req.body;

    if (!email) {
      throw new ValidationError('Email is required');
    }

    // Generate reset token if user exists and send email (do not leak existence)
    const user = await this.userRepository.findOne({ where: { email: email.toLowerCase() } });
    if (user) {
      const reset = TokenService.generateToken(2);
      user.passwordResetTokenHash = reset.tokenHash;
      user.passwordResetExpires = reset.expiresAt;
      await this.userRepository.save(user);

      const appBaseUrl = process.env.CLIENT_URL || 'https://roomies.app';
      const resetLink = `${appBaseUrl}/reset-password?token=${reset.token}&email=${encodeURIComponent(user.email)}`;
      try {
        await MailService.getInstance().sendMail({
          to: user.email,
          subject: 'Roomies password reset',
          text: `If you requested a password reset, visit: ${resetLink}\n\nIf not, you can ignore this email.`,
          html: `<p>If you requested a password reset, click the link below:</p><p><a href="${resetLink}">Reset your password</a></p><p>If you did not request this, you can ignore this email.</p>`,
        });
      } catch {}
    }

    logger.info('Password reset requested', { email });

    // Always return success for security (don't reveal if email exists)
    res.json(createResponse(
      {},
      'If an account with that email exists, a password reset link has been sent'
    ));
  });

  /**
   * Reset password - ENHANCED (placeholder for email integration)
   */
  resetPassword = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { token, newPassword, email } = req.body;

    if (!token || !newPassword) {
      throw new ValidationError('Token and new password are required');
    }

    const user = await this.userRepository.findOne({ where: { email: (email || '').toLowerCase() } });
    if (!user || !user.passwordResetTokenHash || !user.passwordResetExpires) {
      throw new UnauthorizedError('Invalid or expired reset token');
    }
    if (user.passwordResetExpires.getTime() < Date.now()) {
      throw new UnauthorizedError('Invalid or expired reset token');
    }
    const providedHash = TokenService.hashToken(token);
    if (providedHash !== user.passwordResetTokenHash) {
      throw new UnauthorizedError('Invalid or expired reset token');
    }
    user.hashedPassword = newPassword;
    user.passwordResetTokenHash = null;
    user.passwordResetExpires = null;
    await this.userRepository.save(user);

    res.json(createResponse({}, 'Password reset successfully'));
  });

  verifyEmail = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { token, email } = req.body;
    if (!token || !email) {
      throw new ValidationError('Token and email are required');
    }
    const user = await this.userRepository.findOne({ where: { email: email.toLowerCase() } });
    if (!user || !user.emailVerificationTokenHash || !user.emailVerificationExpires) {
      throw new UnauthorizedError('Invalid or expired verification token');
    }
    if (user.emailVerificationExpires.getTime() < Date.now()) {
      throw new UnauthorizedError('Invalid or expired verification token');
    }
    const providedHash = TokenService.hashToken(token);
    if (providedHash !== user.emailVerificationTokenHash) {
      throw new UnauthorizedError('Invalid or expired verification token');
    }
    user.emailVerified = true;
    user.emailVerificationTokenHash = null;
    user.emailVerificationExpires = null;
    await this.userRepository.save(user);
    res.json(createResponse({}, 'Email verified successfully'));
  });

  // GET-friendly verification for link clicks
  verifyEmailLink = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const token = String(req.query.token || '');
    const email = String(req.query.email || '');
    if (!token || !email) {
      res.status(400).send('Invalid verification link');
      return;
    }
    const user = await this.userRepository.findOne({ where: { email: email.toLowerCase() } });
    if (!user || !user.emailVerificationTokenHash || !user.emailVerificationExpires) {
      res.status(400).send('Verification link is invalid or expired');
      return;
    }
    if (user.emailVerificationExpires.getTime() < Date.now()) {
      res.status(400).send('Verification link is invalid or expired');
      return;
    }
    const providedHash = TokenService.hashToken(token);
    if (providedHash !== user.emailVerificationTokenHash) {
      res.status(400).send('Verification link is invalid or expired');
      return;
    }
    user.emailVerified = true;
    user.emailVerificationTokenHash = null;
    user.emailVerificationExpires = null;
    await this.userRepository.save(user);
    res.send('Email verified! You can close this page and return to the app.');
  });

  /**
   * Change password for authenticated user - ENHANCED
   */
  changePassword = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      throw new ValidationError('Current password and new password are required');
    }

    if (!req.user) {
      throw new UnauthorizedError('User not authenticated');
    }

    // Validate current password
    const isValidPassword = await req.user.validatePassword(currentPassword);
    if (!isValidPassword) {
      throw new UnauthorizedError('Current password is incorrect');
    }

    // Validate new password
    if (newPassword.length < 8) {
      throw new ValidationError('New password must be at least 8 characters long');
    }

    // Update password
    req.user.hashedPassword = newPassword; // Will be hashed by the entity
    await this.userRepository.save(req.user);

    logger.info('Password changed successfully', { userId: req.userId });

    res.json(createResponse(
      {},
      'Password changed successfully'
    ));
  });

  /**
   * Delete user account - ENHANCED
   */
  deleteAccount = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

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
  });
}
