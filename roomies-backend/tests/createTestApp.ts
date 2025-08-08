import express from 'express';
import cors from 'cors';
import compression from 'compression';
import { corsConfig, securityMiddlewareStack } from '@/middleware/security';
import authRoutes from '@/routes/auth.routes';
import userRoutes from '@/routes/user.routes';
import householdRoutes from '@/routes/household.routes';
import taskRoutes from '@/routes/task.routes';
import rewardRoutes from '@/routes/reward.routes';
import gamificationRoutes from '@/routes/gamification.routes';
import notificationRoutes from '@/routes/notification.routes';
import eventRoutes from '@/routes/events.routes';
import { AppDataSource } from '@/config/database';
import { errorHandler, notFoundHandler } from '@/middleware/errorHandler';

export async function createTestApp() {
  // Ensure the database is initialized for tests using an in-memory SQLite DB
  if (!AppDataSource.isInitialized) {
    AppDataSource.setOptions({
      // Force SQLite in-memory for isolated, fast tests
      url: undefined as unknown as string, // ensure we do NOT use any Postgres DATABASE_URL
      type: 'sqlite',
      database: ':memory:',
      entities: AppDataSource.options.entities, // keep existing entity metadata
      synchronize: true,
      dropSchema: true,
      logging: false
    } as any);
    await AppDataSource.initialize();
  }

  const app = express();

  // Minimal but representative middleware stack
  // Relax security for tests to avoid HTTPS enforcement and strict headers
  process.env.NODE_ENV = 'test';
  app.disable('x-powered-by');
  // Only minimal middleware for tests
  app.use(cors(corsConfig()));
  app.use(express.json({ limit: '2mb' }));
  app.use(express.urlencoded({ extended: true, limit: '2mb' }));
  app.use(compression({ level: 6 }));

  // Mount routes under /api to match production
  app.use('/api/auth', authRoutes);
  app.use('/api/users', userRoutes);
  app.use('/api/households', householdRoutes);
  app.use('/api/tasks', taskRoutes);
  app.use('/api/rewards', rewardRoutes);
  app.use('/api/gamification', gamificationRoutes);
  app.use('/api/notifications', notificationRoutes);
  app.use('/api/events', eventRoutes);

  // 404 and error handling middleware to match production behavior
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

