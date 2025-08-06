import express, { Request, Response } from 'express';
import { AuthController } from '@/controllers/AuthController';
import { authRateLimiter } from '@/middleware/rateLimiter';
import { asyncHandler, createResponse } from '@/middleware/errorHandler';
import { authenticateToken } from '@/middleware/auth';

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

// Apply rate limiting to all auth routes
router.use(authRateLimiter);

/**
 * @route   POST /api/auth/register
 * @desc    Register a new user
 * @access  Public
 * @body    { email: string, password: string, name: string }
 */
router.post('/register', asyncHandler(async (req: Request, res: Response) => {
  await authController.register(req, res);
}));

/**
 * @route   POST /api/auth/login
 * @desc    Login user and get JWT token
 * @access  Public
 * @body    { email: string, password: string }
 */
router.post('/login', asyncHandler(async (req: Request, res: Response) => {
  await authController.login(req, res);
}));

/**
 * @route   POST /api/auth/refresh
 * @desc    Refresh JWT token
 * @access  Public
 * @body    { refreshToken: string }
 */
router.post('/refresh', asyncHandler(async (req: Request, res: Response) => {
  await authController.refreshToken(req, res);
}));

/**
 * @route   POST /api/auth/logout
 * @desc    Logout user (invalidate token)
 * @access  Private
 */
router.post('/logout', authenticateToken, asyncHandler(async (req: Request, res: Response) => {
  await authController.logout(req, res);
}));

/**
 * @route   GET /api/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
router.get('/me', authenticateToken, asyncHandler(async (req: Request, res: Response) => {
  await authController.getCurrentUser(req, res);
}));

/**
 * @route   POST /api/auth/forgot-password
 * @desc    Request password reset (placeholder for future email integration)
 * @access  Public
 * @body    { email: string }
 */
router.post('/forgot-password', asyncHandler(async (req: Request, res: Response) => {
  await authController.forgotPassword(req, res);
}));

/**
 * @route   POST /api/auth/reset-password
 * @desc    Reset password with token (placeholder for future email integration)
 * @access  Public
 * @body    { token: string, newPassword: string }
 */
router.post('/reset-password', asyncHandler(async (req: Request, res: Response) => {
  await authController.resetPassword(req, res);
}));

/**
 * @route   POST /api/auth/change-password
 * @desc    Change password for authenticated user
 * @access  Private
 * @body    { currentPassword: string, newPassword: string }
 */
router.post('/change-password', authenticateToken, asyncHandler(async (req: Request, res: Response) => {
  await authController.changePassword(req, res);
}));

/**
 * @route   DELETE /api/auth/account
 * @desc    Delete user account
 * @access  Private
 */
router.delete('/account', authenticateToken, asyncHandler(async (req: Request, res: Response) => {
  await authController.deleteAccount(req, res);
}));

export default router;
