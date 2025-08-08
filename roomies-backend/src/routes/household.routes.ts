import express, { Request, Response } from 'express';
import { HouseholdController } from '@/controllers/HouseholdController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler } from '@/middleware/errorHandler';

const router = express.Router();
const householdController = new HouseholdController();

// All household routes require authentication
router.use(authenticateToken);

/**
 * @route   POST /api/households
 * @desc    Create a new household
 * @access  Private
 * @body    { name: string, description?: string }
 */
router.post('/', householdController.createHousehold);

/**
 * @route   POST /api/households/join
 * @desc    Join a household using invite code
 * @access  Private
 * @body    { inviteCode: string }
 */
router.post('/join', householdController.joinHousehold);

/**
 * @route   GET /api/households/current
 * @desc    Get current user's household
 * @access  Private
 */
router.get('/current', householdController.getCurrentHousehold);

/**
 * @route   PUT /api/households/:householdId
 * @desc    Update household information (admin only)
 * @access  Private (Admin)
 * @body    { name?: string, description?: string }
 */
router.put('/:householdId', householdController.updateHousehold);

/**
 * @route   POST /api/households/leave
 * @desc    Leave current household
 * @access  Private
 */
router.post('/leave', householdController.leaveHousehold);

/**
 * @route   GET /api/households/:householdId/members
 * @desc    Get household members
 * @access  Private (Members only)
 */
router.get('/:householdId/members', householdController.getMembers);

/**
 * @route   PUT /api/households/:householdId/members/:memberId/role
 * @desc    Update member role (admin only)
 * @access  Private (Admin)
 * @body    { role: 'admin' | 'member' }
 */
router.put('/:householdId/members/:memberId/role', householdController.updateMemberRole);

export default router;
