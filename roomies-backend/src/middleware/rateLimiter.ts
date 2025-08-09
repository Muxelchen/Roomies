import { Request, Response } from 'express';
import rateLimit from 'express-rate-limit';

import { logger } from '@/utils/logger';

// General API rate limiter
export const rateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests from this IP, please try again later'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req: Request, res: Response) => {
    logger.warn('Rate limit exceeded', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      url: req.url,
      method: req.method
    });
    
    res.status(429).json({
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later'
      }
    });
  }
});

// Stricter rate limiter for authentication endpoints
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit each IP to 5 requests per windowMs for auth
  message: {
    success: false,
    error: {
      code: 'AUTH_RATE_LIMIT_EXCEEDED',
      message: 'Too many authentication attempts, please try again later'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  skipSuccessfulRequests: true, // Don't count successful requests
  handler: (req: Request, res: Response) => {
    logger.warn('Auth rate limit exceeded', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      url: req.url,
      method: req.method
    });
    
    res.status(429).json({
      success: false,
      error: {
        code: 'AUTH_RATE_LIMIT_EXCEEDED',
        message: 'Too many authentication attempts, please try again in 15 minutes'
      }
    });
  }
});

// More permissive rate limiter for public/read-only endpoints
export const publicRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 300, // Higher limit for public endpoints
  message: {
    success: false,
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many requests, please try again later'
    }
  },
  standardHeaders: true,
  legacyHeaders: false
});

// Rate limiter for CloudKit sync endpoints (more restrictive when enabled)
export const cloudSyncRateLimiter = rateLimit({
  windowMs: 5 * 60 * 1000, // 5 minutes
  max: 20, // CloudKit operations can be expensive
  message: {
    success: false,
    error: {
      code: 'CLOUD_SYNC_RATE_LIMIT_EXCEEDED',
      message: 'Too many cloud sync requests, please try again later'
    }
  },
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req: Request) => {
    // Skip rate limiting if CloudKit is disabled
    return process.env.CLOUDKIT_ENABLED !== 'true';
  },
  handler: (req: Request, res: Response) => {
    logger.warn('Cloud sync rate limit exceeded', {
      ip: req.ip,
      userId: req.userId,
      userAgent: req.get('User-Agent'),
      url: req.url,
      method: req.method
    });
    
    res.status(429).json({
      success: false,
      error: {
        code: 'CLOUD_SYNC_RATE_LIMIT_EXCEEDED',
        message: 'Too many cloud sync requests, please try again in a few minutes'
      }
    });
  }
});

// Dynamic rate limiter based on user authentication status
export function dynamicRateLimiter(authenticatedMax: number, anonymousMax: number, windowMs: number = 15 * 60 * 1000) {
  return rateLimit({
    windowMs,
    max: (req: Request) => {
      return req.userId ? authenticatedMax : anonymousMax;
    },
    keyGenerator: (req: Request) => {
      // Use userId for authenticated users, IP for anonymous
      return req.userId || req.ip || 'anonymous';
    },
    message: {
      success: false,
      error: {
        code: 'RATE_LIMIT_EXCEEDED',
        message: 'Too many requests, please try again later'
      }
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req: Request, res: Response) => {
      logger.warn('Dynamic rate limit exceeded', {
        ip: req.ip,
        userId: req.userId,
        isAuthenticated: !!req.userId,
        userAgent: req.get('User-Agent'),
        url: req.url,
        method: req.method
      });
      
      res.status(429).json({
        success: false,
        error: {
          code: 'RATE_LIMIT_EXCEEDED',
          message: req.userId ? 
            'Too many requests from your account, please try again later' : 
            'Too many requests from this IP, please try again later'
        }
      });
    }
  });
}

// Custom rate limiter for expensive operations (like task completion, reward redemption)
export function expensiveOperationLimiter(max: number = 50, windowMs: number = 60 * 60 * 1000) {
  return rateLimit({
    windowMs,
    max,
    keyGenerator: (req: Request) => {
      return req.userId || req.ip || 'anonymous';
    },
    message: {
      success: false,
      error: {
        code: 'OPERATION_RATE_LIMIT_EXCEEDED',
        message: 'Too many operations performed, please try again later'
      }
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req: Request, res: Response) => {
      logger.warn('Expensive operation rate limit exceeded', {
        ip: req.ip,
        userId: req.userId,
        userAgent: req.get('User-Agent'),
        url: req.url,
        method: req.method,
        operation: req.url
      });
      
      res.status(429).json({
        success: false,
        error: {
          code: 'OPERATION_RATE_LIMIT_EXCEEDED',
          message: 'You have performed too many operations recently. Please wait before trying again.'
        }
      });
    }
  });
}
