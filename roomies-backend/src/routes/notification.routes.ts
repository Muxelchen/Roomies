import express from 'express';
import { Request, Response } from 'express';

const router = express.Router();

// Placeholder routes - to be implemented
router.post('/register-device', (req: Request, res: Response) => {
  res.json({ message: 'Notification routes - to be implemented' });
});

export default router;
