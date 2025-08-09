import express from 'express';

import { AppDataSource } from '@/config/database';
import { authenticateToken } from '@/middleware/auth';
import { createResponse , createErrorResponse } from '@/middleware/errorHandler';
import { Activity } from '@/models/Activity';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';

const router = express.Router();

// All gamification routes require authentication
router.use(authenticateToken);

// Simple stats endpoint (can be expanded later)
router.get('/stats', async (req, res) => {
  try {
    const repo = AppDataSource.getRepository(Activity);
    const count = await repo.count();
    res.json(createResponse({ activities: count }, 'Gamification stats'));
  } catch (e) {
    res.json(createResponse({ activities: 0 }, 'Gamification stats'));
  }
});

// Leaderboard for a household
router.get('/leaderboard/:householdId', async (req, res) => {
  try {
    const { householdId } = req.params;
    const membershipRepo = AppDataSource.getRepository(UserHouseholdMembership);
    const members = await membershipRepo.find({ where: { household: { id: householdId }, isActive: true }, relations: ['user'] });

    const leaderboard = members
      .map(m => ({ id: m.user.id, name: m.user.name, points: m.user.points, streakDays: m.user.streakDays }))
      .sort((a, b) => b.points - a.points)
      .slice(0, 50);

    res.json(createResponse({ leaderboard }));
  } catch (e) {
    res.status(500).json(createResponse({ leaderboard: [] }, 'Failed to fetch leaderboard'));
  }
});

// Simple achievements list (derived from badges)
router.get('/achievements', async (req, res) => {
  try {
    const repo = AppDataSource.getRepository(User);
    const user = await repo.findOne({ where: { id: req.userId }, relations: ['badges'] });
    if (!user) return res.status(404).json(createResponse({ achievements: [] }, 'User not found'));
    res.json(createResponse({ achievements: user.badges?.map(b => ({ id: b.id, name: b.name, description: b.description, iconName: b.iconName, color: b.color })) || [] }));
  } catch (e) {
    res.json(createResponse({ achievements: [] }));
  }
});

// Claim an achievement (maps to badges for now)
router.post('/claim-achievement', async (req, res) => {
  try {
    const { badgeId } = req.body || {};
    if (!badgeId) {
      return res.status(400).json(createErrorResponse('badgeId is required', 'VALIDATION_ERROR'));
    }
    const userRepo = AppDataSource.getRepository(User);
    const user = await userRepo.findOne({ where: { id: req.userId }, relations: ['badges'] });
    if (!user) return res.status(404).json(createErrorResponse('User not found', 'USER_NOT_FOUND'));
    // No-op if already has badge
    if (user.badges?.some(b => b.id === badgeId)) {
      return res.json(createResponse({ claimed: true }, 'Achievement already claimed'));
    }
    // Attach badge relation
    const { Badge } = await import('@/models/Badge');
    const badgeRepo = AppDataSource.getRepository(Badge);
    const badge = await badgeRepo.findOne({ where: { id: badgeId } });
    if (!badge) return res.status(404).json(createErrorResponse('Achievement not found', 'ACHIEVEMENT_NOT_FOUND'));
    user.badges = [...(user.badges || []), badge];
    await userRepo.save(user);
    return res.json(createResponse({ claimed: true }));
  } catch (e) {
    return res.status(500).json(createErrorResponse('Failed to claim achievement', 'CLAIM_ERROR'));
  }
});

export default router;
