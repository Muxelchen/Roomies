import { authenticateToken, optionalAuth, requireHousehold, requireHouseholdAdmin, requireResourceOwnership } from '@/middleware/auth';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { generateToken } from '@/utils/jwt';

describe('middleware/auth', () => {
  const next = jest.fn();

  const makeRes = () => {
    const res: any = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    return res;
  };

  it('authenticateToken rejects missing token', async () => {
    const req: any = { headers: {} };
    const res = makeRes();
    await authenticateToken(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('authenticateToken rejects invalid token', async () => {
    const req: any = { headers: { authorization: 'Bearer bad' } };
    const res = makeRes();
    await authenticateToken(req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
  });

  it('optionalAuth continues on invalid token without throwing', async () => {
    const req: any = { headers: { authorization: 'Bearer bad' } };
    const res = makeRes();
    await optionalAuth(req, res, next);
    // Should not set userId
    expect(req.userId).toBeUndefined();
  });

  it('authenticateToken sets user and household when user found; 401 if missing user', async () => {
    const repo = { findOne: jest.fn().mockResolvedValue(null) };
    const spy = jest.spyOn(AppDataSource as any, 'getRepository').mockReturnValue(repo);
    const req1: any = { headers: { authorization: 'Bearer ' + 'bad' } };
    const res1 = makeRes();
    await authenticateToken(req1, res1, next);
    expect(res1.status).toHaveBeenCalledWith(401);

    // Now mock a real user
    const mockUser: Partial<User> = {
      id: 'u1',
      householdMemberships: [ { isActive: true, household: { id: 'h1' }, role: 'admin' } ] as any,
      isHouseholdAdmin: () => true,
      validatePassword: async () => true
    };
    (repo.findOne as jest.Mock).mockResolvedValueOnce(mockUser);
    const token = require('@/utils/jwt').generateToken({ userId: 'u1', email: 'a@b.com' });
    const req2: any = { headers: { authorization: 'Bearer ' + token } };
    const res2 = makeRes();
    await authenticateToken(req2, res2, next);
    expect(req2.userId).toBe('u1');
    spy.mockRestore();
  });

  it('requireHousehold and requireHouseholdAdmin enforce permissions', async () => {
    const res = makeRes();
    const reqNoHousehold: any = {};
    await requireHousehold(reqNoHousehold, res as any, next as any);
    expect(res.status).toHaveBeenCalledWith(403);

    const res2 = makeRes();
    const reqMember: any = { user: { isHouseholdAdmin: () => false }, householdId: 'h1' };
    await requireHouseholdAdmin(reqMember, res2 as any, next as any);
    expect(res2.status).toHaveBeenCalledWith(403);

    const reqAdmin: any = { user: { isHouseholdAdmin: () => true }, householdId: 'h1' };
    const res3 = makeRes();
    const nextSpy = jest.fn();
    await requireHouseholdAdmin(reqAdmin, res3 as any, nextSpy as any);
    expect(nextSpy).toHaveBeenCalled();
  });

  it('requireResourceOwnership sets ownerId', async () => {
    const handler = requireResourceOwnership('id');
    const req: any = { params: { id: 'r1' }, userId: 'u1', body: {} };
    const res = makeRes();
    const nextSpy = jest.fn();
    await handler(req, res as any, nextSpy as any);
    expect(req.body.ownerId).toBe('u1');
    expect(nextSpy).toHaveBeenCalled();
  });
});


