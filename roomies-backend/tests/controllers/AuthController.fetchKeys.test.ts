import { EventEmitter } from 'events';

jest.mock('https', () => ({
  get: (_url: string, cb: (res: any) => void) => {
    const res: any = new EventEmitter();
    res.setEncoding = jest.fn();
    // Simulate async data/end
    process.nextTick(() => {
      cb(res);
      res.emit('data', JSON.stringify({ keys: [{ kid: 'kid1', alg: 'RS256' }] }));
      res.emit('end');
    });
    return { on: jest.fn() };
  }
}));

import { AuthController } from '@/controllers/AuthController';

describe('AuthController.fetchAppleJWKs', () => {
  it('returns parsed JWKs', async () => {
    const controller: any = new AuthController();
    const jwks = await controller.fetchAppleJWKs();
    expect(jwks).toEqual({ keys: [{ kid: 'kid1', alg: 'RS256' }] });
  });
});


