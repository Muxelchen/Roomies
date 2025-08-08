import express from 'express';
import { Request, Response } from 'express';
import CloudKitService from '@/services/CloudKitService';

const router = express.Router();

// Register device token for push notifications via CloudKit (scaffold)
router.post('/register-device', async (req: Request, res: Response) => {
  try {
    const { deviceToken, platform } = req.body || {};
    if (!deviceToken) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'deviceToken is required' } });
    }
    const cloud = CloudKitService.getInstance();
    const status = cloud.getCloudKitStatus();
    if (!status.enabled || !status.available) {
      return res.status(200).json({ success: true, message: 'Cloud not enabled/configured; stored locally only' });
    }
    // TODO: Save device token to CloudKit custom record type 'DeviceToken'
    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ success: false, error: { code: 'REGISTER_DEVICE_ERROR', message: 'Failed to register device' } });
  }
});

export default router;
