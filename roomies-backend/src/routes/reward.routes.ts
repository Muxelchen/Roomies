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
 * @route   POST /api/rewards
 * @desc    Create a reward (admin)
 */
router.post('/', controller.createReward);

/**
 * @route   PUT /api/rewards/:rewardId
 * @desc    Update a reward (admin)
 */
router.put('/:rewardId', validateUUID('rewardId'), controller.updateReward);

/**
 * @route   DELETE /api/rewards/:rewardId
 * @desc    Delete a reward (admin)
 */
router.delete('/:rewardId', validateUUID('rewardId'), controller.deleteReward);

/**
 * @route   POST /api/rewards/:rewardId/redeem
 * @desc    Redeem a reward
 */
router.post('/:rewardId/redeem', validateUUID('rewardId'), controller.redeemReward);

/**
 * @route   GET /api/rewards/history/my
 * @desc    Get current user's redemption history
 */
router.get('/history/my', controller.getMyRedemptionHistory);

export default router;
