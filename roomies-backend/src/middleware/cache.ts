import { Request, Response, NextFunction } from 'express';

import { getCacheService, CacheKeys } from '@/services/CacheService';
import { logger } from '@/utils/logger';

// Extend Express Request to include cache context
declare global {
  namespace Express {
    interface Request {
      cache?: {
        key?: string;
        ttl?: number;
        tags?: string[];
        skip?: boolean;
      };
    }
  }
}

export interface CacheOptions {
  ttl?: number; // Time to live in seconds
  key?: string; // Custom cache key
  keyGenerator?: (req: Request) => string; // Dynamic key generation
  condition?: (req: Request) => boolean; // Condition to cache
  tags?: string[]; // Cache tags for invalidation
  skipOnError?: boolean; // Skip caching on errors
  warmup?: boolean; // Enable cache warmup
}

/**
 * Cache middleware factory
 */
export function cache(options: CacheOptions = {}) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const cacheService = getCacheService();

    // Generate and set cache context first so tests can assert it exists
    const cacheKey = options.key ||
                     (options.keyGenerator && options.keyGenerator(req)) ||
                     generateDefaultKey(req);
    req.cache = {
      key: cacheKey,
      ttl: options.ttl || 3600,
      tags: options.tags,
      skip: false
    };

    // If cache service unavailable, just continue (health fallback)
    if (!cacheService?.isAvailable()) {
      return next();
    }

    // Check condition if provided
    if (options.condition && !options.condition(req)) {
      return next();
    }

    try {
      // Try to get from cache
      const cachedData = await cacheService.get(cacheKey).catch(() => null);
      
      if (cachedData) {
        logger.debug(`Cache hit for key: ${cacheKey}`);
        return res.json(cachedData);
      }

      logger.debug(`Cache miss for key: ${cacheKey}`);

      // Override res.json to cache the response
      const originalJson = res.json.bind(res);
      res.json = function(data: any) {
        // Only cache successful responses
        if (res.statusCode >= 200 && res.statusCode < 300 && !req.cache?.skip) {
          const ttl = req.cache?.ttl || options.ttl || 3600;
          
          // Cache the response asynchronously
          cacheService.set(cacheKey, data, ttl).catch(error => {
            logger.error(`Failed to cache response for key ${cacheKey}:`, error);
          });

          logger.debug(`Cached response for key: ${cacheKey} with TTL: ${ttl}s`);
        }

        return originalJson(data);
      };

    } catch (error) {
      logger.error(`Cache middleware error for key ${cacheKey}:`, error);
      
      if (!options.skipOnError) {
        return next();
      }
    }

    next();
  };
}

/**
 * Cache invalidation middleware
 */
export function invalidateCache(patterns: string | string[] | ((req: Request) => string | string[])) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const cacheService = getCacheService();
    
    if (!cacheService?.isAvailable()) {
      return next();
    }

    // Store original end method
    const originalEnd = res.end.bind(res);
    
    res.end = function(chunk?: any, encoding?: any) {
      // Only invalidate on successful responses
      if (res.statusCode >= 200 && res.statusCode < 300) {
        const invalidationPatterns = typeof patterns === 'function' 
          ? patterns(req) 
          : patterns;
        
        const patternArray = Array.isArray(invalidationPatterns) 
          ? invalidationPatterns 
          : [invalidationPatterns];

        // Invalidate cache asynchronously
        Promise.all(
          patternArray.map(async (pattern) => {
            try {
              // For now, we'll delete specific keys
              // In a more advanced setup, we could implement pattern-based deletion
              await cacheService.delete(pattern);
              logger.debug(`Invalidated cache for pattern: ${pattern}`);
            } catch (error) {
              logger.error(`Failed to invalidate cache for pattern ${pattern}:`, error);
            }
          })
        ).catch(error => {
          logger.error('Cache invalidation error:', error);
        });
      }

      return originalEnd(chunk, encoding);
    };

    next();
  };
}

/**
 * Skip cache for current request
 */
export function skipCache(req: Request, res: Response, next: NextFunction) {
  if (req.cache) {
    req.cache.skip = true;
  }
  next();
}

/**
 * Generate default cache key from request
 */
function generateDefaultKey(req: Request): string {
  const userId = req.userId || 'anonymous';
  const path = req.route?.path || req.path;
  const method = req.method;
  
  // Include query parameters for GET requests
  let queryString = '';
  if (method === 'GET' && Object.keys(req.query).length > 0) {
    queryString = ':' + Object.entries(req.query)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([key, value]) => `${key}=${value}`)
      .join('&');
  }

  return `${method}:${path}:${userId}${queryString}`;
}

/**
 * Cache warming functions for frequently accessed data
 */
export class CacheWarmer {
  private static warmupFunctions: Map<string, () => Promise<void>> = new Map();

  static register(name: string, warmupFunction: () => Promise<void>) {
    this.warmupFunctions.set(name, warmupFunction);
  }

  static async warmAll(): Promise<void> {
    const cacheService = getCacheService();
    
    if (!cacheService?.isAvailable()) {
      logger.warn('Cache not available, skipping warmup');
      return;
    }

    const functions = Array.from(this.warmupFunctions.values());
    await cacheService.warmCache(functions);
  }

  static async warm(names: string[]): Promise<void> {
    const cacheService = getCacheService();
    
    if (!cacheService?.isAvailable()) {
      logger.warn('Cache not available, skipping selective warmup');
      return;
    }

    const functions = names
      .map(name => this.warmupFunctions.get(name))
      .filter((fn): fn is () => Promise<void> => fn !== undefined);

    await cacheService.warmCache(functions);
  }
}

/**
 * Cache statistics middleware for monitoring
 */
export function cacheStats(req: Request, res: Response) {
  const cacheService = getCacheService();
  
  if (!cacheService?.isAvailable()) {
    return res.status(503).json({
      success: false,
      error: {
        message: 'Cache service not available',
        code: 'CACHE_UNAVAILABLE'
      }
    });
  }

  cacheService.getStats()
    .then(stats => {
      res.json({
        success: true,
        data: {
          cache: stats,
          timestamp: new Date().toISOString()
        }
      });
    })
    .catch(error => {
      logger.error('Failed to get cache stats:', error);
      res.status(500).json({
        success: false,
        error: {
          message: 'Failed to retrieve cache statistics',
          code: 'CACHE_STATS_ERROR'
        }
      });
    });
}

/**
 * Cache health check middleware
 */
export async function cacheHealthCheck(req: Request, res: Response, next: NextFunction) {
  const cacheService = getCacheService();
  
  if (!cacheService?.isAvailable()) {
    (req as any).healthChecks = (req as any).healthChecks || {};
    (req as any).healthChecks.cache = {
      status: 'unhealthy',
      message: 'Cache service not available',
      timestamp: new Date().toISOString()
    };
    return next();
  }

  try {
    // Perform a simple cache operation to test connectivity
    const testKey = 'health:check:' + Date.now();
    await cacheService.set(testKey, { test: true }, 10); // 10 second TTL
    const testResult = await cacheService.get(testKey);
    await cacheService.delete(testKey);

    (req as any).healthChecks = (req as any).healthChecks || {};
    (req as any).healthChecks.cache = {
      status: testResult ? 'healthy' : 'degraded',
      message: testResult ? 'Cache operations successful' : 'Cache read failed',
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    (req as any).healthChecks = (req as any).healthChecks || {};
    (req as any).healthChecks.cache = {
      status: 'unhealthy',
      message: `Cache health check failed: ${(error as any).message}`,
      timestamp: new Date().toISOString()
    };
  }

  next();
}

/**
 * Predefined cache configurations for common use cases
 */
export const CacheConfigs = {
  // User profile - cache for 30 minutes
  userProfile: {
    ttl: 30 * 60,
    keyGenerator: (req: Request) => CacheKeys.userProfile(req.userId!),
    condition: (req: Request) => !!req.userId,
    tags: ['user', 'profile']
  },

  // User statistics - cache for 10 minutes
  userStatistics: {
    ttl: 10 * 60,
    keyGenerator: (req: Request) => CacheKeys.userStatistics(req.userId!),
    condition: (req: Request) => !!req.userId,
    tags: ['user', 'statistics']
  },

  // Household data - cache for 15 minutes
  household: {
    ttl: 15 * 60,
    keyGenerator: (req: Request) => {
      if (req.params.householdId) {
        return CacheKeys.household(req.params.householdId);
      }
      // For current household endpoint
      return CacheKeys.household(req.userId! + ':current');
    },
    condition: (req: Request) => !!req.userId,
    tags: ['household']
  },

  // Household members - cache for 20 minutes
  householdMembers: {
    ttl: 20 * 60,
    keyGenerator: (req: Request) => CacheKeys.householdMembers(req.params.householdId),
    condition: (req: Request) => !!req.params.householdId,
    tags: ['household', 'members']
  },

  // User badges - cache for 1 hour
  userBadges: {
    ttl: 60 * 60,
    keyGenerator: (req: Request) => CacheKeys.userBadges(req.userId!),
    condition: (req: Request) => !!req.userId,
    tags: ['user', 'badges']
  },

  // Activity history - cache for 5 minutes due to frequent updates
  activityHistory: {
    ttl: 5 * 60,
    keyGenerator: (req: Request) => {
      const page = req.query.page || '1';
      return CacheKeys.userActivities(req.userId!, parseInt(page as string));
    },
    condition: (req: Request) => !!req.userId,
    tags: ['user', 'activities']
  }
} as const;

/**
 * Cache invalidation patterns for different operations
 */
export const InvalidationPatterns = {
  userUpdate: (req: Request) => [
    CacheKeys.userProfile(req.userId!),
    CacheKeys.userStatistics(req.userId!)
  ],
  
  householdUpdate: (req: Request) => [
    CacheKeys.household(req.params.householdId),
    CacheKeys.householdMembers(req.params.householdId)
  ],
  
  taskUpdate: (req: Request) => [
    CacheKeys.userStatistics(req.userId!),
    CacheKeys.household(req.params.householdId || req.body.householdId),
    CacheKeys.tasksByUser(req.userId!)
  ]
} as const;
