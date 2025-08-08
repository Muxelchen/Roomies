import express from 'express';
import { authenticateToken } from '@/middleware/auth';
import { createResponse } from '@/middleware/errorHandler';
import { AppDataSource } from '@/config/database';
import { Activity } from '@/models/Activity';

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

export default router;
