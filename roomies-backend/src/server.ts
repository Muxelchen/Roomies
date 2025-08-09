import 'reflect-metadata';
import express from 'express';
import cors from 'cors';
import compression from 'compression';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { corsConfig, securityMiddlewareStack } from '@/middleware/security';
import * as Sentry from '@sentry/node';
import { AppDataSource } from '@/config/database';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { verifyToken } from '@/utils/jwt';

import { connectDatabase } from '@/database/connection';
import { errorHandler } from '@/middleware/errorHandler';
import { standardRateLimiter } from '@/middleware/rateLimiter.simple';
import { logger } from '@/utils/logger';
import { healthCheckService } from '@/middleware/healthCheck';
import { createCacheService, getCacheService, CacheConfig } from '@/services/CacheService';
import { CacheWarmer, cacheStats, cacheHealthCheck } from '@/middleware/cache';
import CloudKitService from '@/services/CloudKitService';

// Routes
import authRoutes from '@/routes/auth.routes';
import { createResponse } from '@/middleware/errorHandler';
import userRoutes from '@/routes/user.routes';
import householdRoutes from '@/routes/household.routes';
import taskRoutes from '@/routes/task.routes';
import rewardRoutes from '@/routes/reward.routes';
import gamificationRoutes from '@/routes/gamification.routes';
import notificationRoutes from '@/routes/notification.routes';
import challengeRoutes from '@/routes/challenge.routes';
import eventRoutes from '@/routes/events.routes';

// Load environment variables (.env then optional .env.secure)
dotenv.config();
const secureEnvPath = path.resolve(process.cwd(), '.env.secure');
if (fs.existsSync(secureEnvPath)) {
  // Ensure secure env overrides any .env or process defaults
  dotenv.config({ path: secureEnvPath, override: true });
}

class RoomiesServer {
  private app: express.Application;
  private server: any;
  private io: SocketIOServer;
  private port: number;

  constructor() {
    this.app = express();
    this.port = parseInt(process.env.PORT || '3000', 10);
    this.server = createServer(this.app);
    this.io = new SocketIOServer(this.server, {
      cors: {
        origin: process.env.CLIENT_URL || '*',
        credentials: true
      }
    });
  }

  private async initializeSocketAdapter(): Promise<void> {
    try {
      if (process.env.SOCKET_REDIS_ENABLED !== 'true') {
        return;
      }

      // Use dynamic require to avoid build-time dependency in case adapter isn't installed in some environments
      const { createClient } = require('redis');
      const { createAdapter } = require('@socket.io/redis-adapter');

      const host = process.env.REDIS_HOST || 'localhost';
      const port = parseInt(process.env.REDIS_PORT || '6379', 10);
      const password = process.env.REDIS_PASSWORD;
      const url = process.env.REDIS_URL || `redis://${password ? `:${password}@` : ''}${host}:${port}`;

      const pubClient = createClient({ url });
      const subClient = pubClient.duplicate();
      await pubClient.connect();
      await subClient.connect();

      this.io.adapter(createAdapter(pubClient, subClient));
      logger.info('🔌 Socket.IO Redis adapter enabled');
    } catch (error) {
      logger.warn('⚠️  Socket.IO Redis adapter initialization failed (continuing without adapter)', error);
    }
  }

  private initializeMonitoring(): void {
    try {
      const dsn = process.env.SENTRY_DSN;
      if (dsn) {
        Sentry.init({
          dsn,
          environment: process.env.NODE_ENV || 'development',
          tracesSampleRate: parseFloat(process.env.SENTRY_TRACES_SAMPLE_RATE || '0'),
        });
        logger.info('🛰️  Sentry monitoring initialized');
      }
    } catch (error) {
      logger.warn('⚠️  Failed to initialize Sentry (continuing without it)', error as any);
    }
  }

  private async initializeDatabase(): Promise<void> {
    try {
      await connectDatabase();
      logger.info('Database connected successfully');
    } catch (error) {
      logger.error('Database connection failed:', error);
      process.exit(1);
    }
  }

  private async initializeCache(): Promise<void> {
    try {
      const cacheConfig: CacheConfig = {
        host: process.env.REDIS_HOST || 'localhost',
        port: parseInt(process.env.REDIS_PORT || '6379', 10),
        password: process.env.REDIS_PASSWORD,
        db: parseInt(process.env.REDIS_DB || '0', 10),
        keyPrefix: process.env.REDIS_KEY_PREFIX || 'roomies:',
        lazyConnect: true
      };

      const cacheService = createCacheService(cacheConfig);
      
      // Attempt to connect to Redis
      const connected = await cacheService.connect();
      
      if (connected) {
        logger.info('✅ Redis cache connected successfully');
        
        // Register cache warming functions
        this.registerCacheWarmingFunctions();
        
        // Warm cache in background
        if (process.env.NODE_ENV === 'production') {
          setTimeout(() => {
            CacheWarmer.warmAll().catch(error => {
              logger.error('Cache warming failed:', error);
            });
          }, 5000); // Wait 5 seconds after startup
        }
      } else {
        logger.warn('⚠️  Redis cache connection failed - continuing without cache');
      }
    } catch (error) {
      logger.error('Cache initialization error:', error);
      logger.warn('⚠️  Continuing without cache');
    }
  }

  private registerCacheWarmingFunctions(): void {
    // Register common cache warming functions
    CacheWarmer.register('health', async () => {
      const cacheService = getCacheService();
      if (cacheService) {
        await cacheService.set('warmup:health', { status: 'healthy', timestamp: Date.now() }, 60);
      }
    });
    
    // Add more warming functions as needed for frequently accessed data
    // CacheWarmer.register('commonData', async () => { ... });
  }

  private initializeMiddleware(): void {
    // Monitoring must be initialized before other middleware to capture context
    this.initializeMonitoring();
    // Enhanced Security Stack
    securityMiddlewareStack().forEach(middleware => {
      this.app.use(middleware);
    });

    // CORS with enhanced configuration
    this.app.use(cors(corsConfig()));

    // Body parsing with size limits
    this.app.use(express.json({ 
      limit: process.env.MAX_REQUEST_SIZE || '5mb',
      strict: true,
      type: 'application/json'
    }));
    this.app.use(express.urlencoded({ 
      extended: true,
      limit: process.env.MAX_REQUEST_SIZE || '5mb'
    }));

    // Compression
    this.app.use(compression({
      level: 6,
      threshold: 1024
    }));

    // Serve local uploads when CloudKit is disabled or for local dev
    this.app.use('/uploads', express.static('uploads'));

    // Enhanced Logging
    if (process.env.NODE_ENV !== 'test') {
      this.app.use(morgan('combined', {
        stream: {
          write: (message: string) => {
            logger.info(message.trim());
          }
        }
      }));
    }

    // Rate limiting (skip SSE endpoints to allow long-lived streams)
    this.app.use('/api', (req, res, next) => {
      if (req.path && req.path.startsWith('/events')) {
        return next();
      }
      return (standardRateLimiter as any)(req, res, next);
    });
  }

  private initializeRoutes(): void {
    // Health check endpoints (no rate limiting for monitoring)
    this.app.get('/health', cacheHealthCheck, healthCheckService.performHealthCheck.bind(healthCheckService));
    this.app.get('/health/ready', cacheHealthCheck, healthCheckService.readyCheck.bind(healthCheckService));
    this.app.get('/health/live', cacheHealthCheck, healthCheckService.liveCheck.bind(healthCheckService));
    // Alias for mobile client expecting /api/health
    this.app.get('/api/health', cacheHealthCheck, healthCheckService.performHealthCheck.bind(healthCheckService));
    
    // Cache monitoring endpoints (admin only in production)
    this.app.get('/admin/cache/stats', cacheStats);
    this.app.get('/admin/cache/warm', async (req, res) => {
      try {
        await CacheWarmer.warmAll();
        res.json(createResponse({ timestamp: new Date().toISOString() }, 'Cache warming initiated'));
      } catch (error) {
        res.status(500).json({ success: false, error: { code: 'CACHE_WARM_ERROR', message: 'Cache warming failed' } });
      }
    });
    
    // Legacy health endpoint for backward compatibility
    this.app.get('/ping', (req, res) => {
      res.json(createResponse({ 
        status: 'pong', 
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV
      }));
    });

    // API routes
    this.app.use('/api/auth', authRoutes);
    this.app.use('/api/users', userRoutes);
    this.app.use('/api/households', householdRoutes);
    this.app.use('/api/tasks', taskRoutes);
    this.app.use('/api/rewards', rewardRoutes);
    this.app.use('/api/challenges', challengeRoutes);
    this.app.use('/api/gamification', gamificationRoutes);
    this.app.use('/api/notifications', notificationRoutes);
    // SSE events (under /api/events)
    this.app.use('/api/events', eventRoutes);

    // Cloud status endpoint for frontend awareness
    this.app.get('/api/cloud/status', (req, res) => {
      const cloud = CloudKitService.getInstance();
      const { eventBroker } = require('@/services/EventBroker');
      res.json(createResponse({
        cloud: cloud.getCloudKitStatus(),
        sse: eventBroker.getMetrics()
      }));
    });

    // 404 handler (standardized error envelope)
    this.app.use('*', (req, res) => {
      res.status(404).json({
        success: false,
        error: {
          code: 'NOT_FOUND',
          message: 'Endpoint not found'
        }
      });
    });

    // Error handler
    // Note: Sentry's built-in error handler is optional; custom handler already logs and masks in prod
    this.app.use(errorHandler);
  }

  private initializeSocketIO(): void {
    // Simple JWT auth for Socket.IO connections
    this.io.use((socket, next) => {
      try {
        const authToken =
          (socket.handshake as any).auth?.token ||
          (socket.handshake.query?.token as string | undefined) ||
          ((socket.handshake.headers?.authorization as string | undefined)?.split(' ')[1]);

        if (!authToken) {
          logger.warn('Socket connection rejected: missing token');
          return next(new Error('Authentication required'));
        }

        const payload: any = verifyToken(authToken);
        const userId = payload?.userId || payload?.id || payload?.sub;
        if (!userId) {
          logger.warn('Socket connection rejected: invalid token payload');
          return next(new Error('Invalid token'));
        }

        // Attach to socket context
        (socket.data as any).userId = userId;
        return next();
      } catch (err) {
        logger.warn('Socket connection rejected: token verification failed');
        return next(new Error('Invalid or expired token'));
      }
    });

    this.io.on('connection', (socket) => {
      logger.info(`Client connected: ${socket.id}`);

      // Join household room
      socket.on('join-household', async (householdId: string) => {
        try {
          const userId: string | undefined = (socket.data as any)?.userId;
          if (!userId) return;
          const repo = AppDataSource.getRepository(UserHouseholdMembership);
          const membership = await repo.findOne({
            where: { user: { id: userId }, household: { id: householdId }, isActive: true },
          });
          if (!membership) {
            logger.warn(`Socket ${socket.id} attempted to join unauthorized household ${householdId}`);
            socket.emit('error', { code: 'NOT_A_MEMBER', message: 'Not a member of this household' });
            return;
          }
          socket.join(`household:${householdId}`);
          logger.info(`Socket ${socket.id} joined household ${householdId}`);
        } catch (err) {
          logger.warn('Failed to verify membership for socket join', err as any);
        }
      });

      // Join per-user room
      socket.on('join-user', (userId?: string) => {
        const resolvedUserId = (socket.data as any)?.userId;
        if (!resolvedUserId) return;
        // Only allow joining own user room
        if (userId && userId !== resolvedUserId) {
          logger.warn(`Socket ${socket.id} attempted to join another user's room`);
          return;
        }
        socket.join(`user:${resolvedUserId}`);
        logger.info(`Socket ${socket.id} joined user room ${resolvedUserId}`);
      });

      // Leave household room
      socket.on('leave-household', (householdId: string) => {
        socket.leave(`household:${householdId}`);
        logger.info(`Socket ${socket.id} left household ${householdId}`);
      });

      socket.on('disconnect', () => {
        logger.info(`Client disconnected: ${socket.id}`);
      });
    });

    // Make io available to routes
    this.app.set('io', this.io);
  }

  public async start(): Promise<void> {
    try {
      await this.initializeDatabase();
      await this.initializeCache();
      this.initializeMiddleware();
      this.initializeRoutes();
      this.initializeSocketIO();
      await this.initializeSocketAdapter();

      this.server.listen(this.port, () => {
        logger.info(`
          🏠 Roomies Backend Server
          📡 Running on port ${this.port}
          🌍 Environment: ${process.env.NODE_ENV}
          🔗 API URL: http://localhost:${this.port}
          🔌 WebSocket enabled
          💾 Redis cache available: ${getCacheService()?.isAvailable() ? '✅' : '❌'}
        `);
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  public async stop(): Promise<void> {
    // Clean up cache connection
    const cacheService = getCacheService();
    if (cacheService) {
      await cacheService.disconnect();
      logger.info('Cache disconnected');
    }
    
    this.server.close(() => {
      logger.info('Server stopped');
    });
  }
}

// Start server
const server = new RoomiesServer();
server.start();

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM received, shutting down gracefully');
  await server.stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT received, shutting down gracefully');
  await server.stop();
  process.exit(0);
});

export default server;
