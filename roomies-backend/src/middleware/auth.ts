import { Request, Response, NextFunction } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { verifyToken, extractToken, JWTPayload } from '@/utils/jwt';
import { logger } from '@/utils/logger';

// Extend Express Request to include user
declare global {
  namespace Express {
    interface Request {
      user?: User;
      userId?: string;
      householdId?: string;
    }
  }
}

export async function authenticateToken(req: Request, res: Response, next: NextFunction) {
  try {
    const token = extractToken(req.headers.authorization);
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token required'
      });
    }

    let payload: JWTPayload;
    try {
      payload = verifyToken(token);
    } catch (error) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or expired token'
      });
    }

    // Fetch user from database
    const userRepository = AppDataSource.getRepository(User);
    const user = await userRepository.findOne({
      where: { id: payload.userId },
      relations: ['householdMemberships', 'householdMemberships.household']
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }

    // Attach user info to request
    req.user = user;
    req.userId = user.id;
    
    // Set current household if user has one
    const activeMembership = user.householdMemberships?.find(m => m.isActive);
    if (activeMembership) {
      req.householdId = activeMembership.household.id;
    }

    logger.debug('User authenticated', { userId: user.id, email: user.email });
    next();

  } catch (error) {
    logger.error('Authentication middleware error:', error);
    res.status(500).json({
      success: false,
      message: 'Authentication error'
    });
  }
}

export function requireHousehold(req: Request, res: Response, next: NextFunction) {
  if (!req.householdId) {
    return res.status(403).json({
      success: false,
      message: 'User must be part of a household to access this resource'
    });
  }
  next();
}

export function requireHouseholdAdmin(req: Request, res: Response, next: NextFunction) {
  if (!req.user || !req.householdId) {
    return res.status(403).json({
      success: false,
      message: 'Access denied'
    });
  }

  const isAdmin = req.user.isHouseholdAdmin(req.householdId);
  if (!isAdmin) {
    return res.status(403).json({
      success: false,
      message: 'Admin privileges required'
    });
  }

  next();
}

// Optional authentication - doesn't fail if no token
export async function optionalAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const token = extractToken(req.headers.authorization);
    
    if (token) {
      try {
        const payload = verifyToken(token);
        const userRepository = AppDataSource.getRepository(User);
        const user = await userRepository.findOne({
          where: { id: payload.userId },
          relations: ['householdMemberships', 'householdMemberships.household']
        });

        if (user) {
          req.user = user;
          req.userId = user.id;
          
          const activeMembership = user.householdMemberships?.find(m => m.isActive);
          if (activeMembership) {
            req.householdId = activeMembership.household.id;
          }
        }
      } catch (error) {
        // Ignore token errors in optional auth
        logger.debug('Optional auth token invalid:', error);
      }
    }

    next();
  } catch (error) {
    logger.error('Optional auth middleware error:', error);
    next(); // Continue without authentication
  }
}

// Middleware to check if user owns the resource
export function requireResourceOwnership(resourceParam: string = 'id') {
  return (req: Request, res: Response, next: NextFunction) => {
    const resourceId = req.params[resourceParam];
    const userId = req.userId;

    if (!userId) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    // This is a basic check - specific controllers should implement more detailed ownership checks
    req.body.ownerId = userId;
    next();
  };
}

// CloudKit-specific auth middleware (for when cloud services are available)
export async function authenticateCloudKitToken(req: Request, res: Response, next: NextFunction) {
  // TODO: Implement CloudKit token verification when paid developer account is available
  // For now, fall back to regular authentication
  
  const cloudKitEnabled = process.env.CLOUDKIT_ENABLED === 'true';
  
  if (!cloudKitEnabled) {
    logger.debug('CloudKit authentication disabled, using regular auth');
    return authenticateToken(req, res, next);
  }

  // When CloudKit is available, implement:
  // 1. Verify CloudKit token
  // 2. Extract user information from CloudKit
  // 3. Sync with local user database
  // 4. Set up user context
  
  logger.info('CloudKit authentication not yet implemented, falling back to JWT');
  return authenticateToken(req, res, next);
}

// Rate limiting per user
export function rateLimitPerUser(maxRequests: number = 100, windowMs: number = 15 * 60 * 1000) {
  const requestCounts = new Map<string, { count: number; resetTime: number }>();

  return (req: Request, res: Response, next: NextFunction) => {
    const userId = req.userId;
    if (!userId) {
      return next(); // Skip rate limiting if not authenticated
    }

    const now = Date.now();
    const userLimit = requestCounts.get(userId);

    if (!userLimit || now > userLimit.resetTime) {
      requestCounts.set(userId, { count: 1, resetTime: now + windowMs });
      return next();
    }

    if (userLimit.count >= maxRequests) {
      return res.status(429).json({
        success: false,
        message: 'Too many requests, please try again later'
      });
    }

    userLimit.count++;
    next();
  };
}
