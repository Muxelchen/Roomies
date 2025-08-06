import 'reflect-metadata';
import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import compression from 'compression';
import morgan from 'morgan';
import { createServer } from 'http';
import { Server as SocketIOServer } from 'socket.io';
import dotenv from 'dotenv';

import { connectDatabase } from '@/database/connection';
import { errorHandler } from '@/middleware/errorHandler';
import { rateLimiter } from '@/middleware/rateLimiter';
import { logger } from '@/utils/logger';

// Routes
import authRoutes from '@/routes/auth.routes';
import userRoutes from '@/routes/user.routes';
import householdRoutes from '@/routes/household.routes';
import taskRoutes from '@/routes/task.routes';
import rewardRoutes from '@/routes/reward.routes';
import gamificationRoutes from '@/routes/gamification.routes';
import notificationRoutes from '@/routes/notification.routes';

// Load environment variables
dotenv.config();

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

  private async initializeDatabase(): Promise<void> {
    try {
      await connectDatabase();
      logger.info('Database connected successfully');
    } catch (error) {
      logger.error('Database connection failed:', error);
      process.exit(1);
    }
  }

  private initializeMiddleware(): void {
    // Security
    this.app.use(helmet());
    this.app.use(cors({
      origin: process.env.CLIENT_URL || '*',
      credentials: true
    }));

    // Body parsing
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true }));

    // Compression
    this.app.use(compression());

    // Logging
    if (process.env.NODE_ENV !== 'test') {
      this.app.use(morgan('combined'));
    }

    // Rate limiting
    this.app.use('/api', rateLimiter);
  }

  private initializeRoutes(): void {
    // Health check
    this.app.get('/health', (req, res) => {
      res.json({ 
        status: 'healthy', 
        timestamp: new Date().toISOString(),
        environment: process.env.NODE_ENV
      });
    });

    // API routes
    this.app.use('/api/auth', authRoutes);
    this.app.use('/api/users', userRoutes);
    this.app.use('/api/households', householdRoutes);
    this.app.use('/api/tasks', taskRoutes);
    this.app.use('/api/rewards', rewardRoutes);
    this.app.use('/api/gamification', gamificationRoutes);
    this.app.use('/api/notifications', notificationRoutes);

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({
        success: false,
        message: 'Endpoint not found'
      });
    });

    // Error handler
    this.app.use(errorHandler);
  }

  private initializeSocketIO(): void {
    this.io.on('connection', (socket) => {
      logger.info(`Client connected: ${socket.id}`);

      // Join household room
      socket.on('join-household', (householdId: string) => {
        socket.join(`household:${householdId}`);
        logger.info(`Socket ${socket.id} joined household ${householdId}`);
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
      this.initializeMiddleware();
      this.initializeRoutes();
      this.initializeSocketIO();

      this.server.listen(this.port, () => {
        logger.info(`
          🏠 Roomies Backend Server
          📡 Running on port ${this.port}
          🌍 Environment: ${process.env.NODE_ENV}
          🔗 API URL: http://localhost:${this.port}
          🔌 WebSocket enabled
        `);
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  public async stop(): Promise<void> {
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
