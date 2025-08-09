import Joi from 'joi';

import { AuthController } from '@/controllers/AuthController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler, createResponse } from '@/middleware/errorHandler';
import { 
  authRateLimiter, 
  passwordResetRateLimiter 
} from '@/middleware/rateLimiter.simple';
import { validateRequest, schemas } from '@/middleware/validation';
import express, { Request, Response } from 'express';


const router = express.Router();
const authController = new AuthController();

/**
 * @route   GET /api/auth/health
 * @desc    Health check endpoint for iOS app
 * @access  Public
 */
router.get('/health', (req: Request, res: Response) => {
  res.json(createResponse({ status: 'healthy' }, 'API is working'));
});

// Note: Rate limiting is applied per-route for granular control

/**
 * @route   POST /api/auth/register
 * @desc    Register a new user
 * @access  Public
 * @body    { email: string, password: string, name: string }
 */
router.post('/register', 
  authRateLimiter,  // 5 attempts per 15 minutes
  validateRequest(schemas.register),
  authController.register
);

/**
 * @route   POST /api/auth/login
 * @desc    Login user and get JWT token
 * @access  Public
 * @body    { email: string, password: string }
 */
router.post('/login', 
  authRateLimiter,  // 5 attempts per 15 minutes
  validateRequest(schemas.login),
  authController.login
);

/**
 * @route   POST /api/auth/apple
 * @desc    Sign in with Apple
 * @access  Public
 * @body    { identityToken: string, email?: string, name?: string }
 */
router.post('/apple', 
  authRateLimiter,
  validateRequest(Joi.object({
    identityToken: Joi.string().required(),
    email: Joi.string().email({ tlds: { allow: false } }).optional().lowercase().trim(),
    name: Joi.string().min(1).max(100).optional().trim()
  })),
  authController.appleSignIn
);

/**
 * @route   POST /api/auth/refresh
 * @desc    Refresh JWT token
 * @access  Public
 * @body    { refreshToken: string }
 */
router.post('/refresh', 
  validateRequest(schemas.refreshToken),
  authController.refreshToken
);

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user (invalidate token)
 * @access  Private
 */
router.post('/logout', 
  authenticateToken, 
  authController.logout
);

/**
 * @route   GET /api/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', 
  authenticateToken, 
  authController.getCurrentUser
);

/**
 * @route   POST /api/auth/forgot-password
 * @desc    Request password reset (placeholder for future email integration)
 * @access  Public
 * @body    { email: string }
 */
router.post('/forgot-password', 
  passwordResetRateLimiter,  // 3 attempts per hour
  validateRequest(schemas.forgotPassword),
  authController.forgotPassword
);

/**
 * @route   POST /api/auth/reset-password
 * @desc    Reset password with token (placeholder for future email integration)
 * @access  Public
 * @body    { token: string, newPassword: string }
 */
router.post('/reset-password', 
  passwordResetRateLimiter,  // 3 attempts per hour
  validateRequest(Joi.object({
    email: Joi.string().email({ tlds: { allow: false } }).required().lowercase().trim(),
    token: Joi.string().required(),
    newPassword: Joi.string().min(8).max(128).required().pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
  })),
  authController.resetPassword
);

/**
 * @route   POST /api/auth/verify-email
 * @desc    Verify email with token
 * @access  Public
 * @body    { email: string, token: string }
 */
router.post('/verify-email',
  validateRequest(Joi.object({
    email: Joi.string().email({ tlds: { allow: false } }).required().lowercase().trim(),
    token: Joi.string().required()
  })),
  authController.verifyEmail
);

/**
 * @route   GET /api/auth/verify-email
 * @desc    Verify email via clickable link with query params
 * @access  Public
 * @query   token, email
 */
router.get('/verify-email', authController.verifyEmailLink);

/**
 * @route   POST /api/auth/change-password
 * @desc    Change password for authenticated user
 * @access  Private
 * @body    { currentPassword: string, newPassword: string }
 */
router.post('/change-password', 
  authenticateToken,
  validateRequest(schemas.changePassword),
  authController.changePassword
);

/**
 * @route   DELETE /api/auth/account
 * @desc    Delete user account
 * @access  Private
 */
router.delete('/account', 
  authenticateToken, 
  authController.deleteAccount
);

export default router;
