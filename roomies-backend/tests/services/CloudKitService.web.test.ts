import { EventEmitter } from 'events';

describe('CloudKitService - Web Services signing and requests', () => {
  const originalEnv = process.env;
  let httpsRequestMock: jest.SpyInstance;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };

    // Minimal RSA private key for signing (generated for tests only)
    // For reliability across environments, generate a key dynamically at runtime.
    const { generateKeyPairSync } = require('crypto');
    const { privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
    const privateKeyPem = privateKey.export({ type: 'pkcs1', format: 'pem' }).toString();

    // Set env for Web Services client
    process.env.CLOUDKIT_ENABLED = 'true';
    process.env.CLOUDKIT_USE_WEB_SERVICES = 'true';
    process.env.CLOUDKIT_ENV = 'development';
    process.env.CLOUDKIT_CONTAINER_ID = 'iCloud.de.roomies.HouseholdApp';
    process.env.CLOUDKIT_KEY_ID = 'TESTKEY1234';
    process.env.CLOUDKIT_PRIVATE_KEY = privateKeyPem;

    // Mock https.request to capture headers and body while returning a 200 JSON response
    // We mock after setting env but before importing the service.
    jest.mock('https', () => ({
      request: (...args: any[]) => {
        // args can be (options, callback) or (url, options, callback)
        const options = (args.length === 2 ? args[0] : args[1]) as any;
        const cb = (args.length === 2 ? args[1] : args[2]) as (res: any) => void;
        const res = new EventEmitter() as any;
        res.statusCode = 200;
        process.nextTick(() => {
          cb(res);
          res.emit('data', JSON.stringify({ ok: true, records: [{ id: 'test' }] }));
          res.emit('end');
        });
        const req = new EventEmitter() as any;
        req.write = jest.fn();
        req.end = jest.fn();
        req.on = jest.fn();
        // Attach for assertions
        (req as any).__options = options;
        (global as any).__lastHttpsOptions = options;
        return req;
      }
    }));
  });

  afterEach(() => {
    process.env = originalEnv;
    jest.clearAllMocks();
  });

  it('configures Web Services client and signs requests with headers', async () => {
    let CloudKitService: any;
    await jest.isolateModulesAsync(async () => {
      CloudKitService = (await jest.requireActual('@/services/CloudKitService')).default;
    });
    const service = CloudKitService.getInstance();

    // Status reflects enabled and available
    const statusBefore = service.getCloudKitStatus();
    expect(statusBefore.enabled).toBe(true);
    // Available is true when configured (container id, key id, private key present)
    expect(statusBefore.available).toBe(true);

    // Trigger a cloud write (records/modify)
    const ok = await service.syncHousehold({
      id: 'household-1',
      name: 'Test Household',
      inviteCode: 'INV12345',
      createdAt: new Date(),
      updatedAt: new Date()
    } as any);
    expect(ok).toBe(true);

    // Validate HTTPS options captured by mock
    const opts = (global as any).__lastHttpsOptions as any;
    expect(opts).toBeTruthy();
    expect(opts.hostname).toBe('api.apple-cloudkit.com');
    // Path should include API version, container, env, db and endpoint
    expect(String(opts.path)).toContain('/database/1/');
    expect(String(opts.path)).toContain('/iCloud.de.roomies.HouseholdApp/');
    expect(String(opts.path)).toContain('/development/');
    expect(String(opts.path)).toContain('/public/records/modify');

    // Headers must include Apple CloudKit signing headers
    const headers = opts.headers || {};
    expect(headers['X-Apple-CloudKit-Request-KeyID']).toBe('TESTKEY1234');
    expect(typeof headers['X-Apple-CloudKit-Request-ISO8601Date']).toBe('string');
    expect(headers['X-Apple-CloudKit-Request-Signature']).toBeTruthy();
    expect(headers['Content-Type']).toMatch(/application\/json/);
  });

  it('reports unavailable when required env vars are missing', async () => {
    jest.resetModules();
    process.env = { ...originalEnv, CLOUDKIT_ENABLED: 'true', CLOUDKIT_USE_WEB_SERVICES: 'true' };
    // Intentionally omit container/key/private key
    let CloudKitService: any;
    await jest.isolateModulesAsync(async () => {
      CloudKitService = (await jest.requireActual('@/services/CloudKitService')).default;
    });
    const service = CloudKitService.getInstance();
    const status = service.getCloudKitStatus();
    expect(status.enabled).toBe(true);
    expect(status.available).toBe(false);
    expect(status.error).toBe('CloudKit not configured');
  });
});


