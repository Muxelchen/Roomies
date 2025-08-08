import express, { Request, Response } from 'express';
import { UserController } from '@/controllers/UserController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler } from '@/middleware/errorHandler';

const router = express.Router();
const userController = new UserController();

// All user routes require authentication
router.use(authenticateToken);

/**
 * @route   GET /api/users/profile
 * @desc    Get current user profile with detailed information
 * @access  Private
 */
router.get('/profile', userController.getProfile);

/**
 * @route   PUT /api/users/profile
 * @desc    Update user profile
 * @access  Private
 * @body    { name?: string, avatarColor?: string }
 */
router.put('/profile', userController.updateProfile);

/**
 * @route   GET /api/users/statistics
 * @desc    Get user statistics and achievements
 * @access  Private
 */
router.get('/statistics', userController.getStatistics);

/**
 * @route   GET /api/users/activity
 * @desc    Get user activity history
 * @access  Private
 * @query   { page?: number, limit?: number }
 */
router.get('/activity', userController.getActivityHistory);

/**
 * @route   GET /api/users/badges
 * @desc    Get user badges
 * @access  Private
 */
router.get('/badges', userController.getBadges);

export default router;
