import { Request, Response, NextFunction } from 'express';
import { logger } from '@/utils/logger';

export interface ApiError extends Error {
  statusCode?: number;
  code?: string;
  details?: any;
}

export class ValidationError extends Error {
  statusCode = 400;
  code = 'VALIDATION_ERROR';
  
  constructor(message: string, public details?: any) {
    super(message);
    this.name = 'ValidationError';
  }
}

export class NotFoundError extends Error {
  statusCode = 404;
  code = 'NOT_FOUND';
  
  constructor(message: string = 'Resource not found') {
    super(message);
    this.name = 'NotFoundError';
  }
}

export class UnauthorizedError extends Error {
  statusCode = 401;
  code = 'UNAUTHORIZED';
  
  constructor(message: string = 'Unauthorized') {
    super(message);
    this.name = 'UnauthorizedError';
  }
}

export class ForbiddenError extends Error {
  statusCode = 403;
  code = 'FORBIDDEN';
  
  constructor(message: string = 'Forbidden') {
    super(message);
    this.name = 'ForbiddenError';
  }
}

export class ConflictError extends Error {
  statusCode = 409;
  code = 'CONFLICT';
  
  constructor(message: string = 'Conflict') {
    super(message);
    this.name = 'ConflictError';
  }
}

// CloudKit-specific errors
export class CloudSyncError extends Error {
  statusCode = 503;
  code = 'CLOUD_SYNC_ERROR';
  
  constructor(message: string = 'Cloud synchronization failed') {
    super(message);
    this.name = 'CloudSyncError';
  }
}

export function errorHandler(error: ApiError, req: Request, res: Response, next: NextFunction) {
  // Log error details
  logger.error('API Error:', {
    message: error.message,
    stack: error.stack,
    statusCode: error.statusCode,
    code: error.code,
    details: error.details,
    url: req.url,
    method: req.method,
    userId: req.userId,
    householdId: req.householdId
  });

  // Handle validation errors from class-validator
  if (error.name === 'ValidationError' || (error.message && error.message.toLowerCase().includes('validation'))) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Validation failed',
        details: error.details || error.message
      }
    });
  }

  // Handle database errors
  if (error.name === 'QueryFailedError') {
    return res.status(500).json({
      success: false,
      error: {
        code: 'DATABASE_ERROR',
        message: 'Database operation failed'
      }
    });
  }

  // Handle JWT errors
  if (error.message.includes('jwt') || error.message.includes('token')) {
    return res.status(401).json({
      success: false,
      error: {
        code: 'INVALID_TOKEN',
        message: 'Invalid or expired token'
      }
    });
  }

  // Handle specific error types
  const statusCode = error.statusCode || 500;
  const errorCode = error.code || (statusCode === 500 ? 'INTERNAL_SERVER_ERROR' : 'ERROR');
  
  const errorResponse: any = {
    success: false,
    error: {
      code: errorCode,
      message: error.message
    }
  };

  // Include details for client errors (4xx)
  if (statusCode >= 400 && statusCode < 500 && error.details) {
    errorResponse.error.details = error.details;
  }

  // Don't expose internal error details in production
  if (process.env.NODE_ENV === 'production' && statusCode >= 500) {
    errorResponse.error.message = 'Internal server error';
  }

  res.status(statusCode).json(errorResponse);
}

// Async error handler wrapper
export function asyncHandler(fn: Function) {
  return (req: Request, res: Response, next: NextFunction) => {
    return Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// 404 handler for undefined routes
export function notFoundHandler(req: Request, res: Response) {
  res.status(404).json({
    success: false,
    error: {
      code: 'NOT_FOUND',
      message: `Route ${req.method} ${req.path} not found`
    }
  });
}

// Cloud sync error helpers
export function handleCloudSyncError(error: any, context: string) {
  if (process.env.CLOUDKIT_ENABLED !== 'true') {
    logger.debug(`CloudKit sync skipped for ${context}: CloudKit disabled`);
    return; // Don't throw errors when CloudKit is intentionally disabled
  }

  logger.error(`CloudKit sync failed for ${context}:`, error);
  
  // In development, we might want to continue without cloud sync
  if (process.env.NODE_ENV === 'development') {
    logger.warn('Continuing without cloud sync in development environment');
    return;
  }

  // In production, this might be more critical
  throw new CloudSyncError(`Failed to sync ${context} to cloud storage`);
}

// Helper to create standardized API responses
export function createResponse(data: any, message?: string, pagination?: any) {
  const response: any = {
    success: true,
    data
  };

  if (message) {
    response.message = message;
  }

  if (pagination) {
    response.pagination = pagination;
  }

  return response;
}

// Helper to create error responses
export function createErrorResponse(message: string, code?: string, details?: any) {
  const response: any = {
    success: false,
    error: {
      message,
      code: code || 'ERROR'
    }
  };

  if (details) {
    response.error.details = details;
  }

  return response;
}
