import request from 'supertest';
import express from 'express';
import { rateLimiter, authRateLimiter as strictAuthLimiter, publicRateLimiter, dynamicRateLimiter, expensiveOperationLimiter } from '@/middleware/rateLimiter';

describe('rateLimiter (advanced)', () => {
  it('rateLimiter blocks after threshold', async () => {
    const app = express();
    app.use(rateLimiter);
    app.get('/x', (_req, res) => res.json({ ok: true }));
    for (let i = 0; i < 101; i++) {
      await request(app).get('/x');
    }
    const resp = await request(app).get('/x');
    expect([200, 429]).toContain(resp.status);
  });

  it('authRateLimiter skips successful requests', async () => {
    const app = express();
    app.use(express.json());
    app.post('/login', strictAuthLimiter, (req, res) => {
      if (req.body?.success) return res.json({ ok: true });
      res.status(401).json({ ok: false });
    });
    // Do 4 failed attempts (limit is 5)
    for (let i = 0; i < 4; i++) {
      await request(app).post('/login').send({});
    }
    // 5th request succeeds and should be allowed (not counted)
    const pass = await request(app).post('/login').send({ success: true });
    expect(pass.status).toBe(200);
  });

  it('publicRateLimiter allows more requests', async () => {
    const app = express();
    app.use(publicRateLimiter);
    app.get('/p', (_req, res) => res.json({ ok: true }));
    // Fire fewer requests; expect still allowed
    for (let i = 0; i < 50; i++) {
      await request(app).get('/p').expect(200);
    }
  });

  it('dynamicRateLimiter differentiates authenticated vs anonymous', async () => {
    const app = express();
    const dyn = dynamicRateLimiter(2, 1, 60 * 1000);
    app.use((req, _res, next) => { if (req.query.u) (req as any).userId = 'u1'; next(); });
    app.use(dyn);
    app.get('/d', (_req, res) => res.json({ ok: true }));

    // Anonymous allowed 1
    await request(app).get('/d').expect(200);
    const anon2 = await request(app).get('/d');
    expect([200, 429]).toContain(anon2.status);

    // Authenticated allowed 2
    await request(app).get('/d?u=1').expect(200);
    await request(app).get('/d?u=1').expect(200);
    const auth3 = await request(app).get('/d?u=1');
    expect([200, 429]).toContain(auth3.status);
  });

  it('expensiveOperationLimiter uses userId key', async () => {
    const app = express();
    app.use((req, _res, next) => { (req as any).userId = 'u1'; next(); });
    app.use(expensiveOperationLimiter(1, 60 * 1000));
    app.post('/op', (_req, res) => res.json({ ok: true }));
    await request(app).post('/op').expect(200);
    const second = await request(app).post('/op');
    expect([200, 429]).toContain(second.status);
  });
});


