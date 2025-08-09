import jwtLib from 'jsonwebtoken';
import { generateToken, verifyToken, refreshToken, extractToken, isTokenExpiringSoon } from '@/utils/jwt';

describe('utils/jwt', () => {
  const secret = process.env.JWT_SECRET || 'test-jwt-secret-for-testing-only';

  it('generateToken returns a signed token', () => {
    const token = generateToken({ userId: 'u1', email: 'a@b.com' });
    expect(typeof token).toBe('string');
  });

  it('verifyToken throws on invalid token', () => {
    expect(() => verifyToken('invalid.token')).toThrow('Invalid token');
  });

  it('verifyToken throws on expired token', async () => {
    const expired = jwtLib.sign({ userId: 'u1', email: 'a@b.com' }, secret, { expiresIn: '-1s' });
    expect(() => verifyToken(expired)).toThrow('Token expired');
  });

  it('refreshToken returns new token even if old expired', () => {
    const expired = jwtLib.sign({ userId: 'u1', email: 'a@b.com' }, secret, { expiresIn: '-1s' });
    const refreshed = refreshToken(expired);
    expect(typeof refreshed).toBe('string');
  });

  it('refreshToken returns null on bad token', () => {
    const refreshed = refreshToken('bad');
    expect(refreshed).toBeNull();
  });

  it('extractToken parses Bearer header', () => {
    expect(extractToken('Bearer abc')).toBe('abc');
    expect(extractToken(undefined)).toBeNull();
    expect(extractToken('Token abc')).toBeNull();
  });

  it('isTokenExpiringSoon detects near expiration', () => {
    const long = jwtLib.sign({ userId: 'u1', email: 'a@b.com' }, secret, { expiresIn: '7d' });
    expect(isTokenExpiringSoon(long, 1)).toBe(false);
    const soon = jwtLib.sign({ userId: 'u1', email: 'a@b.com' }, secret, { expiresIn: '1s' });
    expect(isTokenExpiringSoon(soon, 1)).toBe(true);
  });
});


