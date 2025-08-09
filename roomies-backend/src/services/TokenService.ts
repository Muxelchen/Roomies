import crypto from 'crypto';

export type GeneratedToken = {
  token: string;
  tokenHash: string;
  expiresAt: Date;
};

export class TokenService {
  static generateToken(hoursToLive: number = 1): GeneratedToken {
    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = TokenService.hashToken(token);
    const expiresAt = new Date(Date.now() + hoursToLive * 60 * 60 * 1000);
    return { token, tokenHash, expiresAt };
  }

  static hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}

export default TokenService;


