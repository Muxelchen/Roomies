import express from 'express';
import { authenticateToken } from '@/middleware/auth';
import { validateRequest, schemas, validateUUID } from '@/middleware/validation';
import { RewardController } from '@/controllers/RewardController';

const router = express.Router();
const controller = new RewardController();

// All reward routes require authentication
router.use(authenticateToken);

/**
 * @route   GET /api/rewards/household/:householdId
 * @desc    List available rewards for household
 */
router.get('/household/:householdId', validateUUID('householdId'), controller.listHouseholdRewards);

/**
 * @route   POST /api/rewards/:rewardId/redeem
 * @desc    Redeem a reward
 */
router.post('/:rewardId/redeem', validateUUID('rewardId'), controller.redeemReward);

export default router;
