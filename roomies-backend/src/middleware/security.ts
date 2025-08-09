import helmet from 'helmet';

import { logger } from '@/utils/logger';
import { Request, Response, NextFunction } from 'express';

// Extend Request type to include userId
declare module 'express-serve-static-core' {
  interface Request {
    userId?: string;
    user?: any;
  }
}

/**
 * Comprehensive Security Middleware for Roomies Backend
 * Addresses security issues identified in the audit
 */

// HTTPS enforcement middleware
export function enforceHTTPS(req: Request, res: Response, next: NextFunction) {
  // Skip in development and test
  if (process.env.NODE_ENV === 'development' || process.env.NODE_ENV === 'test') {
    return next();
  }

  // Check if request is secure
  const isSecure = req.secure || 
                   req.get('x-forwarded-proto') === 'https' ||
                   req.get('x-forwarded-ssl') === 'on' ||
                   (req.connection && 'encrypted' in req.connection && (req.connection as any).encrypted);

  // Allow health endpoints even if proxy headers are missing
  const isHealth = req.path?.startsWith('/health') || req.path === '/api/health' || req.path === '/ping';
  if (!isSecure && !isHealth) {
    logger.warn('Insecure HTTP request blocked', {
      url: req.url,
      method: req.method,
      ip: req.ip,
      userAgent: req.get('User-Agent')
    });

    return res.status(426).json({
      success: false,
      error: {
        code: 'HTTPS_REQUIRED',
        message: 'HTTPS is required for this endpoint'
      }
    });
  }

  next();
}

// Enhanced helmet configuration
export const securityHeaders = helmet({
  // Content Security Policy
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
      fontSrc: ["'self'", "https://fonts.gstatic.com"],
      imgSrc: ["'self'", "data:", "https:"],
      scriptSrc: ["'self'"],
      objectSrc: ["'none'"],
      mediaSrc: ["'self'"],
      frameSrc: ["'none'"],
      childSrc: ["'none'"],
      workerSrc: ["'none'"],
      connectSrc: ["'self'"],
      baseUri: ["'self'"],
      formAction: ["'self'"],
      frameAncestors: ["'none'"],
      manifestSrc: ["'self'"],
      upgradeInsecureRequests: process.env.NODE_ENV === 'production' ? [] : null
    }
  },

  // HTTP Strict Transport Security
  hsts: {
    maxAge: 63072000, // 2 years
    includeSubDomains: true,
    preload: true
  },

  // X-Frame-Options
  frameguard: {
    action: 'deny'
  },

  // X-Content-Type-Options
  noSniff: true,

  // X-XSS-Protection
  xssFilter: true,

  // Referrer Policy
  referrerPolicy: {
    policy: 'strict-origin-when-cross-origin'
  },

  // X-DNS-Prefetch-Control
  dnsPrefetchControl: {
    allow: false
  },

  // X-Download-Options
  ieNoOpen: true,

  // X-Permitted-Cross-Domain-Policies
  permittedCrossDomainPolicies: false,

  // Hide X-Powered-By header
  hidePoweredBy: true,

  // Note: expectCt has been deprecated in newer helmet versions

  crossOriginEmbedderPolicy: false, // May interfere with file uploads
  crossOriginOpenerPolicy: false,   // May interfere with OAuth flows
  crossOriginResourcePolicy: { policy: 'cross-origin' }
});

// CORS configuration with enhanced security
export function corsConfig() {
  // Allow overriding CORS origins via env vars
  // CLIENT_URL: single origin, CLIENT_ORIGINS: comma-separated list
  const envOriginsRaw = process.env.CLIENT_URL || process.env.CLIENT_ORIGINS || '';
  const envOrigins = envOriginsRaw
    ? envOriginsRaw.split(',').map(o => o.trim()).filter(Boolean)
    : [];

  const defaultProdOrigins = ['https://roomies.app', 'https://www.roomies.app'];
  const defaultDevOrigins = ['http://localhost:3000', 'http://localhost:3001', 'http://127.0.0.1:3000'];

  const allowedOrigins = (
    process.env.NODE_ENV === 'production' ? defaultProdOrigins : defaultDevOrigins
  ).concat(envOrigins);

  return {
    origin: (origin: string | undefined, callback: (err: Error | null, allow?: boolean) => void) => {
      // Allow requests with no origin (like mobile apps or curl requests)
      if (!origin) return callback(null, true);
      
      if (allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        logger.warn('CORS origin blocked', { origin, allowedOrigins });
        callback(new Error('Not allowed by CORS'));
      }
    },
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
    allowedHeaders: [
      'Content-Type', 
      'Authorization', 
      'X-Requested-With',
      'X-API-Key',
      'Cache-Control'
    ],
    exposedHeaders: [
      'X-RateLimit-Limit',
      'X-RateLimit-Remaining',
      'X-RateLimit-Reset',
      'X-Total-Count'
    ],
    credentials: true,
    maxAge: 86400, // 24 hours
    optionsSuccessStatus: 200
  };
}

// Request sanitization middleware
export function sanitizeRequest(req: Request, res: Response, next: NextFunction) {
  // Remove potentially dangerous headers
  const dangerousHeaders = [
    'x-forwarded-host',
    'x-cluster-client-ip',
    'x-real-ip'
  ];

  dangerousHeaders.forEach(header => {
    if (req.headers[header] && process.env.NODE_ENV === 'production') {
      delete req.headers[header];
    }
  });

  // Limit request body size (already handled by express.json, but double-check)
  if (req.headers['content-length']) {
    const contentLength = parseInt(req.headers['content-length']);
    const maxSize = 10 * 1024 * 1024; // 10MB
    
    if (contentLength > maxSize) {
      logger.warn('Request body too large', {
        contentLength,
        maxSize,
        url: req.url,
        method: req.method,
        ip: req.ip
      });

      return res.status(413).json({
        success: false,
        error: {
          code: 'PAYLOAD_TOO_LARGE',
          message: 'Request body too large'
        }
      });
    }
  }

  next();
}

// Security logging middleware
export function securityLogger(req: Request, res: Response, next: NextFunction) {
  // Log sensitive operations
  const sensitiveEndpoints = [
    '/auth/register',
    '/auth/login',
    '/auth/change-password',
    '/auth/reset-password',
    '/auth/delete-account'
  ];

  const isSensitive = sensitiveEndpoints.some(endpoint => req.url.includes(endpoint));
  
  if (isSensitive) {
    logger.info('Security-sensitive request', {
      method: req.method,
      url: req.url,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      userId: req.userId,
      timestamp: new Date().toISOString()
    });
  }

  // Log failed authentication attempts
  const originalJson = res.json;
  res.json = function(body: any) {
    if (body && body.success === false && body.error && 
        (body.error.code === 'INVALID_CREDENTIALS' || 
         body.error.code === 'INVALID_TOKEN' ||
         body.error.code === 'UNAUTHORIZED')) {
      
      logger.warn('Authentication failure', {
        method: req.method,
        url: req.url,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        errorCode: body.error.code,
        timestamp: new Date().toISOString()
      });
    }
    
    return originalJson.call(this, body);
  };

  next();
}

// IP whitelist middleware (for admin endpoints)
export function ipWhitelist(allowedIPs: string[] = []) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (allowedIPs.length === 0) {
      return next(); // No whitelist configured
    }

    const clientIP = req.ip || req.connection.remoteAddress || '';
    
    if (!allowedIPs.includes(clientIP)) {
      logger.warn('IP not whitelisted', {
        clientIP,
        allowedIPs,
        url: req.url,
        method: req.method
      });

      return res.status(403).json({
        success: false,
        error: {
          code: 'IP_NOT_ALLOWED',
          message: 'Access denied from this IP address'
        }
      });
    }

    next();
  };
}

// Request ID middleware for tracing
export function requestId(req: Request, res: Response, next: NextFunction) {
  const requestId = req.get('X-Request-ID') || 
                   `${Date.now()}-${Math.random().toString(36).substring(7)}`;
  
  (req as any).requestId = requestId;
  res.set('X-Request-ID', requestId);
  
  next();
}

// Content type validation middleware
export function validateContentType(allowedTypes: string[] = ['application/json']) {
  return (req: Request, res: Response, next: NextFunction) => {
    if (['POST', 'PUT', 'PATCH'].includes(req.method)) {
      const contentType = req.get('content-type');
      
      if (!contentType || !allowedTypes.some(type => contentType.includes(type))) {
        return res.status(415).json({
          success: false,
          error: {
            code: 'UNSUPPORTED_MEDIA_TYPE',
            message: `Content-Type must be one of: ${allowedTypes.join(', ')}`
          }
        });
      }
    }
    
    next();
  };
}

// Comprehensive security middleware stack
export function securityMiddlewareStack() {
  return [
    requestId,
    enforceHTTPS,
    securityHeaders,
    sanitizeRequest,
    securityLogger,
    validateContentType()
  ];
}
