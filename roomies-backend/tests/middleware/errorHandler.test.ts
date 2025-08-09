import { errorHandler, notFoundHandler, ValidationError, handleCloudSyncError, CloudSyncError } from '@/middleware/errorHandler';

describe('errorHandler middleware', () => {
  const createMockReq = (overrides: any = {}) => ({
    url: '/api/test',
    method: 'GET',
    userId: 'user-1',
    householdId: 'household-1',
    path: '/api/test',
    ...overrides,
  } as any);

  const createMockRes = () => {
    const res: any = {};
    res.status = jest.fn().mockReturnValue(res);
    res.json = jest.fn().mockReturnValue(res);
    res.send = jest.fn().mockReturnValue(res);
    return res;
  };

  const next = jest.fn();

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('handles ValidationError specifically', () => {
    const err = new ValidationError('Invalid');
    const req = createMockReq();
    const res = createMockRes();
    errorHandler(err as any, req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' })
    }));
  });

  it('handles QueryFailedError as database error', () => {
    const err = { name: 'QueryFailedError', message: 'db failed' } as any;
    const req = createMockReq();
    const res = createMockRes();
    errorHandler(err, req, res, next);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'DATABASE_ERROR' })
    }));
  });

  it('handles JWT/token errors with 401', () => {
    const err = { message: 'jwt malformed' } as any;
    const req = createMockReq();
    const res = createMockRes();
    errorHandler(err, req, res, next);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_TOKEN' })
    }));
  });

  it('includes details for 4xx errors', () => {
    const err = { message: 'bad request', statusCode: 400, code: 'BAD', details: { field: 'name' } } as any;
    const req = createMockReq();
    const res = createMockRes();
    errorHandler(err, req, res, next);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BAD', details: { field: 'name' } })
    }));
  });

  it('masks 500 errors in production', () => {
    const prevEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = 'production';
    const err = { message: 'boom' } as any;
    const req = createMockReq();
    const res = createMockRes();
    errorHandler(err, req, res, next);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ message: 'Internal server error' })
    }));
    process.env.NODE_ENV = prevEnv;
  });
});

describe('notFoundHandler', () => {
  it('returns 404 with route info', () => {
    const req = { method: 'POST', path: '/missing' } as any;
    const res: any = { status: jest.fn().mockReturnThis(), json: jest.fn() };
    notFoundHandler(req, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ message: expect.stringContaining('POST /missing') })
    }));
  });
});

describe('handleCloudSyncError', () => {
  const prevEnv = { ...process.env };
  afterEach(() => {
    process.env = { ...prevEnv };
  });

  it('returns silently when CloudKit disabled', () => {
    process.env.CLOUDKIT_ENABLED = 'false';
    expect(() => handleCloudSyncError(new Error('x'), 'ctx')).not.toThrow();
  });

  it('does not throw in development when CloudKit enabled', () => {
    process.env.CLOUDKIT_ENABLED = 'true';
    process.env.NODE_ENV = 'development';
    expect(() => handleCloudSyncError(new Error('x'), 'ctx')).not.toThrow();
  });

  it('throws CloudSyncError in production when CloudKit enabled', () => {
    process.env.CLOUDKIT_ENABLED = 'true';
    process.env.NODE_ENV = 'production';
    expect(() => handleCloudSyncError(new Error('x'), 'ctx')).toThrow(CloudSyncError);
  });
});


