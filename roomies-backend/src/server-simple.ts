import 'reflect-metadata';
import express from 'express';
import cors from 'cors';
import { logger } from '@/utils/logger';
import { connectDatabase } from '@/database/connection';
import { standardRateLimiter } from '@/middleware/rateLimiter.simple';

// Routes - importing only auth routes for now
import authRoutes from '@/routes/auth.routes';

const app = express();
const port = parseInt(process.env.PORT || '3001', 10);

// Basic middleware only
app.use(cors({
  origin: ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true
}));

app.use(express.json({ limit: '5mb' }));
app.use(express.urlencoded({ extended: true, limit: '5mb' }));

// Apply rate limiting to API routes only
app.use('/api', standardRateLimiter);

// Simple health check
app.get('/ping', (req, res) => {
  res.json({ 
    status: 'pong', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV 
  });
});

// API routes
app.use('/api/auth', authRoutes);

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint not found'
  });
});

// Simple error handler
app.use((error: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  logger.error('Server error:', error);
  res.status(500).json({
    success: false,
    error: {
      message: 'Internal server error',
      code: 'INTERNAL_ERROR'
    }
  });
});

async function startServer() {
  try {
    // Connect to database
    await connectDatabase();
    logger.info('✅ Database connected');

    app.listen(port, () => {
      logger.info(`
        🏠 Roomies Backend (Simple Mode)
        📡 Running on port ${port}
        🌍 Environment: ${process.env.NODE_ENV}
        🔗 API URL: http://localhost:${port}
      `);
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();

export default app;
