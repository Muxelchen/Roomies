import express, { Request, Response } from 'express';

import { HouseholdController } from '@/controllers/HouseholdController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler } from '@/middleware/errorHandler';
import { validateRequest, schemas, validateUUID } from '@/middleware/validation';

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
router.post('/', validateRequest(schemas.createHousehold), householdController.createHousehold);

/**
 * @route   POST /api/households/join
 * @desc    Join a household using invite code
 * @access  Private
 * @body    { inviteCode: string }
 */
router.post('/join', validateRequest(schemas.joinHousehold), householdController.joinHousehold);

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
router.get('/:householdId', validateUUID('householdId'), householdController.getHouseholdById);

/**
 * @route   PUT /api/households/:householdId
 * @desc    Update household information (admin only)
 * @access  Private (Admin)
 * @body    { name?: string, description?: string }
 */
router.put('/:householdId', validateUUID('householdId'), validateRequest(schemas.updateHousehold), householdController.updateHousehold);

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
router.get('/:householdId/members', validateUUID('householdId'), householdController.getMembers);

/**
 * @route   PUT /api/households/:householdId/members/:memberId/role
 * @desc    Update member role (admin only)
 * @access  Private (Admin)
 * @body    { role: 'admin' | 'member' }
 */
router.put('/:householdId/members/:memberId/role', validateUUID('householdId'), validateRequest(schemas.updateMemberRole), householdController.updateMemberRole);

/**
 * @route   DELETE /api/households/:householdId/members/:memberId
 * @desc    Remove a member (admin only)
 */
router.delete('/:householdId/members/:memberId', validateUUID('householdId'), validateUUID('memberId'), householdController.removeMember);

/**
 * @route   POST /api/households/:householdId/invite
 * @desc    Get or regenerate invite code (admin only)
 */
router.post('/:householdId/invite', validateUUID('householdId'), householdController.getInvite);

export default router;
