import express from 'express';
import { Request, Response } from 'express';

const router = express.Router();

// Placeholder routes - to be implemented
router.get('/', (req: Request, res: Response) => {
  res.json({ message: 'Reward routes - to be implemented' });
});

export default router;
