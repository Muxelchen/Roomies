/**
 * Separate suite for Apple Sign-In success path where we need to mock crypto.createPublicKey
 * before importing the controller module (named import binding).
 */

import TokenService from '@/services/TokenService';

// Only mock createPublicKey while preserving other crypto methods used elsewhere (e.g., randomBytes)
jest.mock('crypto', () => {
  const actual = jest.requireActual('crypto');
  return {
    ...actual,
    createPublicKey: jest.fn(() => ({
      export: () => '-----BEGIN PUBLIC KEY-----\nTEST\n-----END PUBLIC KEY-----\n'
    }))
  };
});

// Mock DB repository
jest.mock('@/config/database', () => ({
  AppDataSource: {
    getRepository: jest.fn(() => ({
      findOne: jest.fn()
        .mockResolvedValueOnce(null) // by appleUserId
        .mockResolvedValueOnce(null), // by email
      create: jest.fn((data: any) => ({ ...data, id: 'new-user-id' })),
      save: jest.fn(async (u: any) => u)
    })),
    isInitialized: true
  }
}));

// Mock logger to reduce noise
jest.mock('@/utils/logger', () => ({
  logger: { info: jest.fn(), error: jest.fn(), warn: jest.fn(), debug: jest.fn() }
}));

// Mock JWT verify to always succeed
jest.mock('jsonwebtoken', () => ({
  __esModule: true,
  default: {
    decode: jest.fn(() => ({ header: { kid: 'kid1', alg: 'RS256' } })),
    verify: jest.fn(() => ({
      sub: 'apple-user-123',
      email: 'apple@example.com',
      email_verified: 'true',
      iss: 'https://appleid.apple.com',
      aud: process.env.APP_BUNDLE_ID || 'de.roomies.HouseholdApp'
    })),
    sign: jest.fn(() => 'mock-jwt-token')
  }
}));

// Import controller after mocks
import { AuthController } from '@/controllers/AuthController';

describe('AuthController - Apple Sign-In success (isolated)', () => {
  const authController = new AuthController();

  // Spy fetchAppleJWKs to provide a matching JWK
  beforeAll(() => {
    jest.spyOn(authController as any, 'fetchAppleJWKs').mockResolvedValue({
      keys: [{ kid: 'kid1', kty: 'RSA', alg: 'RS256', n: 'test', e: 'AQAB' }]
    });
  });

  it('creates a new user and responds with token', async () => {
    const req: any = {
      body: { identityToken: 'id-token', email: 'apple@example.com', name: 'Apple User' }
    };
    const res: any = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    const next = jest.fn();

    await authController.appleSignIn(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });
});


