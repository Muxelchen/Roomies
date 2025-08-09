import { ValidationError } from '@/middleware/errorHandler';
import { logger } from '@/utils/logger';
import { Request, Response, NextFunction } from 'express';

export interface PaginationParams {
  page: number;
  limit: number;
  offset: number;
  sortBy: string;
  sortOrder: 'ASC' | 'DESC';
}

export interface PaginationResult {
  currentPage: number;
  totalPages: number;
  totalItems: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
  itemsPerPage: number;
}

/**
 * Pagination middleware to prevent unbounded queries
 * Addresses audit finding: "Unbounded queries in activities, tasks, households"
 */
export function paginationMiddleware(options?: {
  defaultLimit?: number;
  maxLimit?: number;
  allowedSortFields?: string[];
}) {
  const defaultLimit = options?.defaultLimit || 20;
  const maxLimit = options?.maxLimit || 100;
  const allowedSortFields = options?.allowedSortFields || ['createdAt', 'updatedAt', 'name', 'title'];

      return (req: Request, res: Response, next: NextFunction) => {
    try {
      const page = Math.max(1, parseInt(req.query.page as string) || 1);
      let limit = parseInt(req.query.limit as string) || defaultLimit;
          const sortBy = (req.query.sortBy as string)?.trim() || 'createdAt';
      const sortOrder = ((req.query.sortOrder as string)?.toUpperCase() === 'ASC') ? 'ASC' : 'DESC';

      // Enforce maximum limit to prevent abuse
      if (limit > maxLimit) {
        logger.warn('Pagination limit exceeded maximum', {
          requestedLimit: limit,
          maxLimit,
          userAgent: req.get('User-Agent'),
          ip: req.ip,
          url: req.url
        });
        limit = maxLimit;
      }

      // Validate sort field to prevent SQL injection and ensure column exists
          if (!allowedSortFields.includes(sortBy)) {
        throw new ValidationError(`Invalid sort field. Allowed fields: ${allowedSortFields.join(', ')}`);
      }

      const offset = (page - 1) * limit;

      // Add pagination parameters to request object
      req.pagination = {
        page,
        limit,
        offset,
        sortBy,
        sortOrder
      };

      logger.debug('Pagination applied', {
        page,
        limit,
        offset,
        sortBy,
        sortOrder,
        url: req.url
      });

      next();
      } catch (error) {
        next(error);
      }
  };
}

/**
 * Helper function to create standardized pagination response
 */
export function createPaginationResponse(
  total: number,
  page: number,
  limit: number
): PaginationResult {
  const totalPages = Math.ceil(total / limit);
  
  return {
    currentPage: page,
    totalPages,
    totalItems: total,
    hasNextPage: page < totalPages,
    hasPreviousPage: page > 1,
    itemsPerPage: limit
  };
}

/**
 * Cursor-based pagination for high-performance queries
 * Better for real-time data and large datasets
 */
export function cursorPaginationMiddleware(options?: {
  defaultLimit?: number;
  maxLimit?: number;
  cursorField?: string;
}) {
  const defaultLimit = options?.defaultLimit || 20;
  const maxLimit = options?.maxLimit || 100;
  const cursorField = options?.cursorField || 'createdAt';

  return (req: Request, res: Response, next: NextFunction) => {
    try {
      let limit = parseInt(req.query.limit as string) || defaultLimit;
      const cursor = req.query.cursor as string;
      const direction = ((req.query.direction as string)?.toLowerCase() === 'prev') ? 'prev' : 'next';

      // Enforce maximum limit
      if (limit > maxLimit) {
        limit = maxLimit;
      }

      req.cursorPagination = {
        limit,
        cursor,
        direction,
        cursorField
      };

      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Middleware specifically for activity feeds (most performance-critical)
 */
export function activityPaginationMiddleware() {
  return paginationMiddleware({
    defaultLimit: 20,
    maxLimit: 50, // Smaller limit for activity feeds
    allowedSortFields: ['createdAt', 'points', 'type']
  });
}

/**
 * Middleware for task lists
 */
export function taskPaginationMiddleware() {
  return paginationMiddleware({
    defaultLimit: 20,
    maxLimit: 100,
    allowedSortFields: ['createdAt', 'updatedAt', 'dueDate', 'priority', 'title', 'points', 'isCompleted']
  });
}

/**
 * Middleware for user/member lists
 */
export function memberPaginationMiddleware() {
  return paginationMiddleware({
    defaultLimit: 20,
    maxLimit: 100,
    allowedSortFields: ['name', 'points', 'level', 'streakDays', 'lastActivity', 'joinedAt']
  });
}

/**
 * Performance monitoring for pagination
 */
export function paginationMonitoringMiddleware() {
  return (req: Request, res: Response, next: NextFunction) => {
    const startTime = Date.now();
    
    // Hook into response to measure performance
    const originalJson = res.json;
    res.json = function(body: any) {
      const duration = Date.now() - startTime;
      
      // Log slow pagination queries
      if (duration > 1000) {
        logger.warn('Slow pagination query detected', {
          url: req.url,
          method: req.method,
          duration,
          pagination: req.pagination,
          userAgent: req.get('User-Agent'),
          ip: req.ip
        });
      }
      
      // Add performance headers
      res.set('X-Query-Duration', duration.toString());
      if (req.pagination) {
        res.set('X-Page', req.pagination.page.toString());
        res.set('X-Per-Page', req.pagination.limit.toString());
      }
      
      return originalJson.call(this, body);
    };
    
    next();
  };
}

/**
 * Search pagination with additional filtering capabilities
 */
export function searchPaginationMiddleware(options?: {
  searchFields?: string[];
  filterFields?: string[];
}) {
  const searchFields = options?.searchFields || ['title', 'name', 'description'];
  const filterFields = options?.filterFields || [];

  return (req: Request, res: Response, next: NextFunction) => {
    try {
      // Apply base pagination
      paginationMiddleware()(req, res, () => {});

      const search = req.query.search as string;
      const filters: Record<string, any> = {};

      // Extract filter parameters
      for (const field of filterFields) {
        if (req.query[field]) {
          filters[field] = req.query[field];
        }
      }

      req.searchPagination = {
        ...req.pagination!,
        search,
        filters,
        searchFields
      };

      next();
    } catch (error) {
      next(error);
    }
  };
}

/**
 * Infinite scroll pagination helper
 */
export function infiniteScrollMiddleware() {
  return cursorPaginationMiddleware({
    defaultLimit: 15,
    maxLimit: 50
  });
}

// Extend Express Request interface
declare global {
  namespace Express {
    interface Request {
      pagination?: PaginationParams;
      cursorPagination?: {
        limit: number;
        cursor?: string;
        direction: 'next' | 'prev';
        cursorField: string;
      };
      searchPagination?: PaginationParams & {
        search?: string;
        filters: Record<string, any>;
        searchFields: string[];
      };
    }
  }
}
