import express from 'express';
import request from 'supertest';
import { paginationMiddleware, createPaginationResponse } from '@/middleware/pagination';

describe('pagination middleware', () => {
  it('applies defaults and caps limit; rejects bad sort field', async () => {
    const app = express();
    app.get('/items', paginationMiddleware({ defaultLimit: 10, maxLimit: 50 }), (req, res) => {
      res.json({ pagination: req.pagination });
    });

    const ok = await request(app).get('/items?page=2&limit=999&sortBy=createdAt&sortOrder=asc');
    expect(ok.status).toBe(200);
    expect(ok.body.pagination.limit).toBe(50);
    expect(ok.body.pagination.page).toBe(2);
    expect(ok.body.pagination.sortOrder).toBe('ASC');

    const bad = await request(app).get('/items?sortBy=badfield');
    expect(bad.status).toBe(400);
  });

  it('createPaginationResponse returns correct flags', () => {
    const resp = createPaginationResponse(120, 2, 50);
    expect(resp.totalPages).toBe(3);
    expect(resp.hasNextPage).toBe(true);
    expect(resp.hasPreviousPage).toBe(true);
  });
});


