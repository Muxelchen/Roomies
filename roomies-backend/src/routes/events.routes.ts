import express from 'express';
import rateLimit from 'express-rate-limit';

import { AppDataSource } from '@/config/database';
import { authenticateToken } from '@/middleware/auth';
import { createResponse } from '@/middleware/errorHandler';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import CloudKitService from '@/services/CloudKitService';
import { eventBroker } from '@/services/EventBroker';
import { logger } from '@/utils/logger';

const router = express.Router();

// All event routes require auth
router.use(authenticateToken);

// Basic connection rate limit per IP
const sseLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false
});
router.use(sseLimiter);

router.get('/household/:householdId', async (req, res) => {
  const { householdId } = req.params;
  const userId = (req as any).userId as string | undefined;

  if (!userId) {
    return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'Unauthorized' } });
  }

  try {
    // Verify membership
    const repo = AppDataSource.getRepository(UserHouseholdMembership);
    const membership = await repo.findOne({ where: { user: { id: userId }, household: { id: householdId }, isActive: true } });
    if (!membership) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Forbidden' } });
    }

    // Per-user connection cap per household
    const userConnections = eventBroker.getUserClientCount(householdId, userId);
    if (userConnections >= 3) {
      return res.status(429).json({ success: false, error: { code: 'SSE_LIMIT', message: 'Too many event streams open' } });
    }

    // Set headers for SSE
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    // Disable proxy buffering (nginx) and compression interference
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();

    const clientId = `${userId}-${Date.now()}-${Math.random().toString(36).slice(2)}`;
    eventBroker.addClient(householdId, clientId, userId, req.ip, res);

    // Send a hello event
    res.write(`event: hello\n`);
    res.write(`data: ${JSON.stringify({ message: 'connected', clientId, ts: Date.now() })}\n\n`);
    // Suggest client reconnection interval (ms)
    res.write(`retry: 3000\n\n`);

    // Heartbeat to keep connection alive
    const interval = setInterval(() => {
      try {
        res.write(`event: ping\n`);
        res.write(`data: ${JSON.stringify({ ts: Date.now() })}\n\n`);
      } catch (err) {
        logger.warn('Failed to write heartbeat to SSE client', { clientId, err });
      }
    }, 25000);

    // Cleanup on close
    req.on('close', () => {
      clearInterval(interval);
      eventBroker.removeClient(householdId, clientId);
      try { res.end(); } catch {}
    });
  } catch (err) {
    logger.error('SSE connection error', err as any);
    res.status(500).json({ success: false, error: { code: 'SSE_ERROR', message: 'SSE setup failed' } });
  }
});

export default router;

// Health/status for events and cloud
router.get('/status', (req, res) => {
  const cloud = CloudKitService.getInstance();
  res.json(createResponse({
    cloud: cloud.getCloudKitStatus(),
    sse: eventBroker.getMetrics()
  }));
});
