import { HouseholdController } from '@/controllers/HouseholdController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler } from '@/middleware/errorHandler';
import express, { Request, Response } from 'express';

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
 * @route   GET /api/households/:householdId
 * @desc    Get a specific household (members only)
 */
router.get('/:householdId', householdController.getHouseholdById);

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

/**
 * @route   DELETE /api/households/:householdId/members/:memberId
 * @desc    Remove a member (admin only)
 */
router.delete('/:householdId/members/:memberId', householdController.removeMember);

/**
 * @route   POST /api/households/:householdId/invite
 * @desc    Get or regenerate invite code (admin only)
 */
router.post('/:householdId/invite', householdController.getInvite);

export default router;
