import express from 'express';
import { Request, Response } from 'express';

const router = express.Router();

// Placeholder routes - to be implemented
router.get('/stats', (req: Request, res: Response) => {
  res.json({ message: 'Gamification routes - to be implemented' });
});

export default router;
