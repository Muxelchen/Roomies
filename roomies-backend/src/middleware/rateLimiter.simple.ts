/**
 * Simplified Rate Limiting Middleware (Memory-based)
 * Addresses: CRITICAL P0 - No Rate Limiting vulnerability
 * Note: Uses memory store for now, will upgrade to Redis later
 */

import rateLimit from 'express-rate-limit';

import { logger } from '@/utils/logger';
import { Request, Response } from 'express';

// Extend Request type to include userId
declare module 'express-serve-static-core' {
  interface Request {
    userId?: string;
    user?: any;
  }
}

/**
 * Create a custom key generator based on user ID or IP
 */
const keyGenerator = (req: Request): string => {
  // Use user ID if authenticated, otherwise use IP
  if (req.userId) {
    return `user:${req.userId}`;
  }
  return req.ip || req.socket.remoteAddress || 'unknown';
};

/**
 * Custom handler for rate limit exceeded
 */
const rateLimitHandler = (req: Request, res: Response) => {
  logger.warn('Rate limit exceeded', {
    userId: req.userId,
    ip: req.ip,
    path: req.path,
    method: req.method
  });

  res.status(429).json({
    success: false,
    error: {
      message: 'Too many requests. Please try again later.',
      code: 'RATE_LIMIT_EXCEEDED',
      retryAfter: res.getHeader('Retry-After')
    }
  });
};

/**
 * Standard rate limiter for general API endpoints
 * 100 requests per 15 minutes
 */
export const standardRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Max requests per window
  message: 'Too many requests from this IP/user, please try again later.',
  standardHeaders: true, // Return rate limit info in headers
  legacyHeaders: false,
  keyGenerator,
  handler: rateLimitHandler,
  skip: (req: Request) => {
    // Skip rate limiting for health checks
    return req.path === '/health' || req.path === '/api/health' || req.path === '/api/auth/health';
  }
});

/**
 * Strict rate limiter for authentication endpoints
 * 5 attempts per 15 minutes
 */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Max 5 login attempts
  message: 'Too many authentication attempts, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) => {
    // For auth, use email if provided, otherwise IP
    const email = req.body?.email;
    if (email) {
      return `email:${email}`;
    }
    return req.ip || req.socket.remoteAddress || 'unknown';
  },
  handler: rateLimitHandler,
  skipSuccessfulRequests: true // Don't count successful logins
});

/**
 * Password reset rate limiter
 * 3 attempts per hour per email
 */
export const passwordResetRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 3, // Max 3 reset attempts per hour
  message: 'Too many password reset attempts, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req: Request) => {
    const email = req.body?.email || req.params?.email;
    return `reset:${email || req.ip}`;
  },
  handler: rateLimitHandler
});

/**
 * Create operation rate limiter
 * Prevents spam creation of resources
 */
export const createOperationRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 50, // Max 50 creates per hour
  message: 'Too many creation requests, please slow down.',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  handler: rateLimitHandler
});

/**
 * File upload rate limiter
 * 10 uploads per hour
 */
export const uploadRateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Max 10 uploads per hour
  message: 'Upload limit exceeded, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator,
  handler: rateLimitHandler
});

export default {
  standard: standardRateLimiter,
  auth: authRateLimiter,
  passwordReset: passwordResetRateLimiter,
  createOperation: createOperationRateLimiter,
  upload: uploadRateLimiter
};
