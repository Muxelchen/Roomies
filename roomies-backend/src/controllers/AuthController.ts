import { createPublicKey } from 'crypto';
import https from 'https';

import { validate } from 'class-validator';
import { Request, Response } from 'express';
import jwt, { JwtHeader } from 'jsonwebtoken';

import { AppDataSource } from '@/config/database';
import { 
  ValidationError, 
  UnauthorizedError, 
  ConflictError, 
  createResponse,
  createErrorResponse,
  asyncHandler
} from '@/middleware/errorHandler';
import { HouseholdTask } from '@/models/HouseholdTask';
import { RefreshToken } from '@/models/RefreshToken';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import MailService from '@/services/MailService';
import TokenService from '@/services/TokenService';
import { generateToken, refreshToken as refreshJWT } from '@/utils/jwt';
import { logger } from '@/utils/logger';




export class AuthController {
  private userRepository = AppDataSource.getRepository(User);
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  private refreshTokenRepository = AppDataSource.getRepository(RefreshToken);

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
      // Throw ConflictError so centralized error handler returns standardized envelope
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

    // Issue refresh token when enabled
    let refreshTokenValue: string | undefined;
    if (process.env.ENABLE_REFRESH_TOKENS === 'true') {
      const rt = TokenService.generateToken(24 * 30); // 30 days
      refreshTokenValue = rt.token;
      const refreshEntity = new RefreshToken();
      refreshEntity.tokenHash = TokenService.hashToken(rt.token);
      refreshEntity.expiresAt = rt.expiresAt;
      (refreshEntity as any).user = user;
      try { await this.refreshTokenRepository.save(refreshEntity); } catch {}
    }

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
      // Provide a refreshToken when enabled; iOS falls back to token otherwise
      refreshToken: refreshTokenValue || token
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

    // Issue refresh token when enabled
    let refreshTokenValue: string | undefined;
    if (process.env.ENABLE_REFRESH_TOKENS === 'true') {
      const rt = TokenService.generateToken(24 * 30); // 30 days
      refreshTokenValue = rt.token;
      const refreshEntity = new RefreshToken();
      refreshEntity.tokenHash = TokenService.hashToken(rt.token);
      refreshEntity.expiresAt = rt.expiresAt;
      (refreshEntity as any).user = user;
      try { await this.refreshTokenRepository.save(refreshEntity); } catch {}
    }

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
      // Provide a refreshToken when enabled; fallback to token
      refreshToken: refreshTokenValue || token
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

    if (process.env.ENABLE_REFRESH_TOKENS === 'true') {
      // Verify against DB when enabled
      const tokenHash = TokenService.hashToken(refreshToken);
      const record = await this.refreshTokenRepository.findOne({ where: { tokenHash }, relations: ['user'] });
      if (!record || !record.isActive) {
        throw new UnauthorizedError('Invalid refresh token');
      }
      const newToken = generateToken({ userId: record.user.id, email: record.user.email });
      res.json(createResponse({ token: newToken, refreshToken }, 'Token refreshed successfully'));
      return;
    }

    // Fallback stateless refresh
    const { refreshToken: runtimeRefresh } = require('@/utils/jwt');
    const newToken = runtimeRefresh(refreshToken);
    if (!newToken) {
      throw new UnauthorizedError('Invalid refresh token');
    }
    res.json(createResponse({ token: newToken }, 'Token refreshed successfully'));
  });

  /**
   * Logout user - ENHANCED
   */
  logout = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    // Optionally revoke provided refresh token when feature enabled
    try {
      if (process.env.ENABLE_REFRESH_TOKENS === 'true') {
        const maybeToken = (req.body && (req.body.refreshToken as string)) || undefined;
        if (maybeToken) {
          const tokenHash = TokenService.hashToken(maybeToken);
          await this.refreshTokenRepository
            .createQueryBuilder()
            .update(require('@/models/RefreshToken').RefreshToken)
            .set({ revokedAt: () => 'CURRENT_TIMESTAMP' } as any)
            .where('token_hash = :tokenHash AND revoked_at IS NULL', { tokenHash })
            .execute();
        }
      }
    } catch (e) {
      logger.warn('Refresh token revoke failed on logout (continuing):', e as any);
    }

    logger.info('User logged out', { userId: req.userId });
    res.json(createResponse({}, 'Logged out successfully'));
  });

  /**
   * Sign in with Apple (native iOS flow)
   * Expects an Apple identityToken (JWT) from iOS ASAuthorizationAppleIDCredential
   */
  appleSignIn = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { identityToken, email: providedEmail, name: providedName } = req.body || {};

    if (!identityToken || typeof identityToken !== 'string') {
      throw new ValidationError('identityToken is required');
    }

    // Decode header to get kid and alg
    const decoded = jwt.decode(identityToken, { complete: true }) as { header: JwtHeader; payload: any } | null;
    if (!decoded || !decoded.header || !decoded.header.kid) {
      throw new UnauthorizedError('Invalid Apple identity token');
    }

    const kid = decoded.header.kid as string;
    const alg = decoded.header.alg as string;

    // Fetch Apple JWKs and find the matching key
    const jwks = await this.fetchAppleJWKs();
    const jwk = jwks.keys?.find((k: any) => k.kid === kid && (!alg || k.alg === alg || (k.alg == null && alg === 'RS256')));
    if (!jwk) {
      throw new UnauthorizedError('Apple signing key not found');
    }

    // Convert JWK to PEM using Node crypto
    let publicPem: string;
    try {
      const pubKey = createPublicKey({ key: jwk as any, format: 'jwk' } as any);
      publicPem = pubKey.export({ type: 'spki', format: 'pem' }).toString();
    } catch (e) {
      logger.error('Failed to convert Apple JWK to PEM', e as any);
      throw new UnauthorizedError('Apple key conversion failed');
    }

    // Verify token
    const defaultAudience = 'de.roomies.HouseholdApp';
    const expectedAudience = (process.env.NODE_ENV === 'production')
      ? (process.env.APP_BUNDLE_ID || '')
      : (process.env.APP_BUNDLE_ID || defaultAudience);
    if (process.env.NODE_ENV === 'production' && !expectedAudience) {
      logger.error('APP_BUNDLE_ID is required in production for Apple Sign-In');
      throw new UnauthorizedError('Server misconfiguration');
    }
    let applePayload: any;
    try {
      applePayload = jwt.verify(identityToken, publicPem, {
        algorithms: ['RS256'],
        issuer: 'https://appleid.apple.com',
        audience: expectedAudience
      });
    } catch (e) {
      logger.warn('Apple identity token verification failed', e as any);
      throw new UnauthorizedError('Invalid or expired Apple identity token');
    }

    // Extract claims
    const appleUserId: string = applePayload.sub;
    const emailFromToken: string | undefined = applePayload.email;
    const emailVerifiedClaim: any = applePayload.email_verified;
    const isEmailVerified: boolean = String(emailVerifiedClaim).toLowerCase() === 'true';

    // Resolve email and name
    const email = (providedEmail || emailFromToken || '').toLowerCase().trim() || undefined;
    const name = (providedName || (email ? email.split('@')[0] : 'Apple User')).toString().trim();

    // Find or create user
    let user: User | null = null;

    // Try by appleUserId first
    user = await this.userRepository.findOne({ where: { appleUserId } as any, relations: ['householdMemberships', 'householdMemberships.household'] });

    // If not found, try by email
    if (!user && email) {
      user = await this.userRepository.findOne({ where: { email }, relations: ['householdMemberships', 'householdMemberships.household'] });
    }

    if (!user) {
      // Create a new user with random password
      const randomPassword = TokenService.generateToken(24).token; // secure random
      user = this.userRepository.create({
        email: email || `${appleUserId}@privaterelay.appleid.com`,
        name: name || 'Apple User',
        hashedPassword: randomPassword,
        avatarColor: ['blue', 'green', 'orange', 'purple', 'red', 'teal', 'pink'][Math.floor(Math.random() * 7)],
        points: 0,
        streakDays: 0,
        emailVerified: isEmailVerified
      });
      (user as any).appleUserId = appleUserId;
      await this.userRepository.save(user);
      logger.info('New user created via Sign in with Apple', { userId: user.id, email: user.email });
    } else {
      // Link apple id if missing
      if (!(user as any).appleUserId) {
        (user as any).appleUserId = appleUserId;
      }
      if (isEmailVerified && !user.emailVerified) {
        user.emailVerified = true;
      }
      await this.userRepository.save(user);
      logger.info('User signed in via Sign in with Apple', { userId: user.id, email: user.email });
    }

    // Determine household context
    const activeMembership = user.householdMemberships?.find(m => m.isActive);
    const householdId = activeMembership?.household?.id;

    // Generate JWT for our API
    const token = generateToken({
      userId: user.id,
      email: user.email,
      householdId,
      role: activeMembership?.role
    });

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
      refreshToken: token
    }, 'Login with Apple successful'));
  });

  private fetchAppleJWKs(): Promise<any> {
    return new Promise((resolve, reject) => {
      https.get('https://appleid.apple.com/auth/keys', (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            resolve(json);
          } catch (e) {
            reject(e);
          }
        });
      }).on('error', reject);
    });
  }

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

    const userId = req.userId;

    // Deactivate household memberships (leave households)
    try {
      await this.membershipRepository
        .createQueryBuilder()
        .update(UserHouseholdMembership)
        .set({ isActive: false, leftAt: () => 'CURRENT_TIMESTAMP' } as any)
        .where('user_id = :userId AND is_active = :active', { userId, active: true })
        .execute();
    } catch (e) {
      logger.error('Failed to deactivate memberships during account deletion', e as any);
    }

    // Unassign tasks assigned to this user
    try {
      await this.taskRepository
        .createQueryBuilder()
        .update(HouseholdTask)
        .set({ assignedTo: null } as any)
        .where('assigned_to = :userId', { userId })
        .execute();
    } catch (e) {
      logger.error('Failed to unassign tasks during account deletion', e as any);
    }

    // Anonymize user (soft delete)
    try {
      const user = await this.userRepository.findOne({ where: { id: userId } });
      if (user) {
        const anonEmail = `deleted+${user.id}@roomies.app`;
        user.email = anonEmail;
        user.name = 'Deleted User';
        user.avatarColor = 'blue';
        user.points = 0;
        user.streakDays = 0;
        user.lastActivity = new Date();
        user.appleUserId = null;
        user.emailVerificationTokenHash = null;
        user.emailVerificationExpires = null;
        user.passwordResetTokenHash = null;
        user.passwordResetExpires = null;
        // Set a random password; entity hook will hash it
        user.hashedPassword = TokenService.generateToken(24).token;
        await this.userRepository.save(user);
      }
    } catch (e) {
      logger.error('Failed to anonymize user during account deletion', e as any);
    }

    // Revoke all refresh tokens for this user
    try {
      if (process.env.ENABLE_REFRESH_TOKENS === 'true') {
        await this.refreshTokenRepository
          .createQueryBuilder()
          .update(require('@/models/RefreshToken').RefreshToken)
          .set({ revokedAt: () => 'CURRENT_TIMESTAMP' } as any)
          .where('user_id = :userId AND revoked_at IS NULL', { userId })
          .execute();
      }
    } catch (e) {
      logger.warn('Failed to revoke user refresh tokens during account deletion', e as any);
    }

    logger.info('Account deleted (anonymized) successfully', { userId });

    res.json(createResponse({}, 'Account deleted'));
  });
}
