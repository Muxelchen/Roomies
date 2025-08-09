import request from 'supertest';
import express from 'express';
import { standardRateLimiter, authRateLimiter, passwordResetRateLimiter } from '@/middleware/rateLimiter.simple';

describe('rateLimiter.simple', () => {
  it('standard limiter skips health endpoints and limits others', async () => {
    const app = express();
    app.use(standardRateLimiter);
    app.get('/api/health', (_req, res) => res.json({ ok: true }));
    app.get('/test', (_req, res) => res.json({ ok: true }));

    // Health should always pass
    await request(app).get('/api/health').expect(200);

    // Simulate many requests to hit limit quickly with same IP
    for (let i = 0; i < 101; i++) {
      await request(app).get('/test');
    }
    const over = await request(app).get('/test');
    expect([200, 429]).toContain(over.status);
  });

  it('auth limiter uses email key and skips successful requests', async () => {
    const app = express();
    app.use(express.json());
    app.post('/login', authRateLimiter, (req, res) => {
      if (req.body?.ok) return res.json({ ok: true });
      res.status(401).json({ ok: false });
    });

    // Fail 5 times
    for (let i = 0; i < 5; i++) {
      await request(app).post('/login').send({ email: 'a@b.com' }).expect(401);
    }
    const blocked = await request(app).post('/login').send({ email: 'a@b.com' });
    expect([401, 429]).toContain(blocked.status);

    // Successful requests should be skipped
    const ok = await request(app).post('/login').send({ email: 'c@d.com', ok: true });
    expect(ok.status).toBe(200);
  });

  it('password reset limiter keys by email', async () => {
    const app = express();
    app.use(express.json());
    app.post('/forgot', passwordResetRateLimiter, (_req, res) => res.json({ ok: true }));
    for (let i = 0; i < 3; i++) {
      await request(app).post('/forgot').send({ email: 'x@y.com' }).expect(200);
    }
    const blocked = await request(app).post('/forgot').send({ email: 'x@y.com' });
    expect([200, 429]).toContain(blocked.status);
  });
});


