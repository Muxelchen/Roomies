import express from 'express';
import { authenticateToken } from '@/middleware/auth';
import { validateUUID } from '@/middleware/validation';
import { ChallengeController } from '@/controllers/ChallengeController';

const router = express.Router();
const controller = new ChallengeController();

// All challenge routes require authentication
router.use(authenticateToken);

/**
 * @route   GET /api/challenges/household/:householdId
 * @desc    List active challenges for household
 */
router.get('/household/:householdId', validateUUID('householdId'), controller.listActive);

/**
 * @route   POST /api/challenges/:challengeId/join
 * @desc    Join a challenge
 */
router.post('/:challengeId/join', validateUUID('challengeId'), controller.join);

export default router;

