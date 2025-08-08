import jwt from 'jsonwebtoken';

export function generateTestJWT(payload: any = {}, options: jwt.SignOptions = {}) {
  const secret = process.env.JWT_SECRET || 'test-jwt-secret-for-testing-only';
  const defaultPayload = { sub: payload.sub || 'test-user', ...payload };
  return jwt.sign(defaultPayload, secret, { expiresIn: '1h', ...options });
}

