import { User } from '../models/User';

declare global {
  namespace Express {
    interface Request {
      user?: User;
      userId?: string;
      file?: {
        fieldname: string;
        originalname: string;
        encoding: string;
        mimetype: string;
        size: number;
        buffer?: Buffer;
        path?: string;
        destination?: string;
        filename?: string;
      };
    }
  }
}
