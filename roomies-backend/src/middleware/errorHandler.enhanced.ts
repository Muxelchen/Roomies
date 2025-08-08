/**
 * Enhanced Global Error Handler
 * Addresses: CRITICAL P0 - No try-catch blocks in codebase
 */

import { Request, Response, NextFunction } from 'express';
import { ValidationError as ClassValidatorError } from 'class-validator';
import { QueryFailedError, EntityNotFoundError } from 'typeorm';
import { JsonWebTokenError, TokenExpiredError } from 'jsonwebtoken';
import { logger } from '@/utils/logger';
import * as Sentry from '@sentry/node';

// Initialize Sentry if DSN provided
if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  });
}

/**
 * Custom error classes for better error handling
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly isOperational: boolean;
  public readonly details?: any;

  constructor(
    message: string,
    statusCode: number = 500,
    code: string = 'INTERNAL_ERROR',
    isOperational: boolean = true,
    details?: any
  ) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = isOperational;
    this.details = details;

    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, details?: any) {
    super(message, 400, 'VALIDATION_ERROR', true, details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message: string = 'Unauthorized access') {
    super(message, 401, 'UNAUTHORIZED', true);
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Access forbidden') {
    super(message, 403, 'FORBIDDEN', true);
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super(message, 404, 'NOT_FOUND', true);
  }
}

export class ConflictError extends AppError {
  constructor(message: string = 'Resource conflict') {
    super(message, 409, 'CONFLICT', true);
  }
}

export class RateLimitError extends AppError {
  constructor(message: string = 'Too many requests') {
    super(message, 429, 'RATE_LIMIT_EXCEEDED', true);
  }
}

export class ServiceUnavailableError extends AppError {
  constructor(message: string = 'Service temporarily unavailable') {
    super(message, 503, 'SERVICE_UNAVAILABLE', true);
  }
}

/**
 * Error response formatter
 */
interface ErrorResponse {
  success: false;
  error: {
    message: string;
    code: string;
    statusCode: number;
    timestamp: string;
    path?: string;
    method?: string;
    details?: any;
    stack?: string;
    requestId?: string;
  };
}

/**
 * Generate a unique request ID for tracking
 */
const generateRequestId = (): string => {
  return `req_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
};

/**
 * Sanitize error details to prevent information leakage
 */
const sanitizeErrorDetails = (error: any, isDevelopment: boolean): any => {
  if (isDevelopment) {
    return error;
  }

  // Remove sensitive fields in production
  const sanitized = { ...error };
  delete sanitized.password;
  delete sanitized.token;
  delete sanitized.secret;
  delete sanitized.apiKey;
  delete sanitized.credentials;
  
  return sanitized;
};

/**
 * Convert various error types to AppError
 */
const normalizeError = (error: any): AppError => {
  // Already an AppError
  if (error instanceof AppError) {
    return error;
  }

  // TypeORM errors
  if (error instanceof QueryFailedError) {
    const message = 'Database query failed';
    const details = process.env.NODE_ENV === 'development' ? error.message : undefined;
    return new AppError(message, 400, 'DATABASE_ERROR', true, details);
  }

  if (error instanceof EntityNotFoundError) {
    return new NotFoundError('Entity not found');
  }

  // JWT errors
  if (error instanceof TokenExpiredError) {
    return new UnauthorizedError('Token has expired');
  }

  if (error instanceof JsonWebTokenError) {
    return new UnauthorizedError('Invalid token');
  }

  // Validation errors from class-validator
  if (Array.isArray(error) && error[0] instanceof ClassValidatorError) {
    const messages = error.map(err => Object.values(err.constraints || {}).join(', '));
    return new ValidationError('Validation failed', messages);
  }

  // MongoDB/Mongoose errors
  if (error.name === 'MongoError' || error.name === 'MongoServerError') {
    if (error.code === 11000) {
      return new ConflictError('Duplicate entry');
    }
    return new AppError('Database error', 500, 'DATABASE_ERROR', true);
  }

  // Default to internal server error
  return new AppError(
    error.message || 'An unexpected error occurred',
    error.statusCode || 500,
    error.code || 'INTERNAL_ERROR',
    false
  );
};

/**
 * Global error handler middleware
 */
export const globalErrorHandler = (
  error: any,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const requestId = generateRequestId();
  const normalizedError = normalizeError(error);
  const isDevelopment = process.env.NODE_ENV === 'development';
  const showStack = isDevelopment && process.env.ERROR_EXPOSE_STACK !== 'false';

  // Log error details
  const errorLog = {
    requestId,
    message: normalizedError.message,
    code: normalizedError.code,
    statusCode: normalizedError.statusCode,
    method: req.method,
    path: req.path,
    query: req.query,
    body: sanitizeErrorDetails(req.body, isDevelopment),
    userId: req.userId,
    ip: req.ip,
    userAgent: req.get('user-agent'),
    timestamp: new Date().toISOString(),
    stack: normalizedError.stack
  };

  // Log based on error severity
  if (normalizedError.statusCode >= 500) {
    logger.error('Server error occurred', errorLog);
    
    // Send to Sentry in production
    if (process.env.NODE_ENV === 'production' && !normalizedError.isOperational) {
      Sentry.captureException(error, {
        user: { id: req.userId },
        extra: errorLog
      });
    }
  } else if (normalizedError.statusCode >= 400) {
    logger.warn('Client error occurred', errorLog);
  } else {
    logger.info('Error occurred', errorLog);
  }

  // Prepare error response
  const errorResponse: ErrorResponse = {
    success: false,
    error: {
      message: normalizedError.message,
      code: normalizedError.code,
      statusCode: normalizedError.statusCode,
      timestamp: new Date().toISOString(),
      path: req.path,
      method: req.method,
      requestId
    }
  };

  // Add additional details in development
  if (isDevelopment) {
    errorResponse.error.details = sanitizeErrorDetails(normalizedError.details, true);
    if (showStack) {
      errorResponse.error.stack = normalizedError.stack;
    }
  }

  // Send response
  res.status(normalizedError.statusCode).json(errorResponse);
};

/**
 * Async handler wrapper to catch errors in async route handlers
 * This ensures all async errors are caught
 */
export const asyncHandler = (fn: Function) => {
  return (req: Request, res: Response, next: NextFunction) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

/**
 * Try-catch wrapper for non-Express async operations
 */
export const tryCatchWrapper = async <T>(
  operation: () => Promise<T>,
  errorMessage: string = 'Operation failed',
  errorCode: string = 'OPERATION_ERROR'
): Promise<T | null> => {
  try {
    return await operation();
  } catch (error) {
    logger.error(`${errorMessage}:`, error);
    throw new AppError(errorMessage, 500, errorCode, false, error);
  }
};

/**
 * Safe JSON parse with error handling
 */
export const safeJsonParse = <T = any>(
  jsonString: string,
  defaultValue: T | null = null
): T | null => {
  try {
    return JSON.parse(jsonString) as T;
  } catch (error) {
    logger.warn('JSON parse error:', { jsonString, error });
    return defaultValue;
  }
};

/**
 * Database transaction wrapper with automatic rollback
 */
export const withTransaction = async <T>(
  operation: (manager: any) => Promise<T>
): Promise<T> => {
  const queryRunner = AppDataSource.createQueryRunner();
  await queryRunner.connect();
  await queryRunner.startTransaction();

  try {
    const result = await operation(queryRunner.manager);
    await queryRunner.commitTransaction();
    return result;
  } catch (error) {
    await queryRunner.rollbackTransaction();
    logger.error('Transaction rolled back:', error);
    throw error;
  } finally {
    await queryRunner.release();
  }
};

/**
 * Retry mechanism for flaky operations
 */
export const retryOperation = async <T>(
  operation: () => Promise<T>,
  maxRetries: number = 3,
  delay: number = 1000,
  backoff: number = 2
): Promise<T> => {
  let lastError: any;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      logger.warn(`Operation failed, attempt ${attempt}/${maxRetries}:`, error);

      if (attempt < maxRetries) {
        const waitTime = delay * Math.pow(backoff, attempt - 1);
        await new Promise(resolve => setTimeout(resolve, waitTime));
      }
    }
  }

  throw new AppError(
    `Operation failed after ${maxRetries} attempts`,
    500,
    'RETRY_EXHAUSTED',
    false,
    lastError
  );
};

/**
 * Circuit breaker pattern for external service calls
 */
export class CircuitBreaker {
  private failures: number = 0;
  private successCount: number = 0;
  private lastFailureTime: Date | null = null;
  private state: 'CLOSED' | 'OPEN' | 'HALF_OPEN' = 'CLOSED';

  constructor(
    private readonly threshold: number = 5,
    private readonly timeout: number = 60000, // 1 minute
    private readonly resetTimeout: number = 30000 // 30 seconds
  ) {}

  async execute<T>(operation: () => Promise<T>): Promise<T> {
    if (this.state === 'OPEN') {
      if (Date.now() - (this.lastFailureTime?.getTime() || 0) > this.resetTimeout) {
        this.state = 'HALF_OPEN';
      } else {
        throw new ServiceUnavailableError('Service circuit breaker is open');
      }
    }

    try {
      const result = await operation();
      this.onSuccess();
      return result;
    } catch (error) {
      this.onFailure();
      throw error;
    }
  }

  private onSuccess(): void {
    this.failures = 0;
    this.successCount++;
    if (this.state === 'HALF_OPEN') {
      this.state = 'CLOSED';
    }
  }

  private onFailure(): void {
    this.failures++;
    this.lastFailureTime = new Date();
    
    if (this.failures >= this.threshold) {
      this.state = 'OPEN';
      logger.error(`Circuit breaker opened after ${this.failures} failures`);
    }
  }

  getState(): string {
    return this.state;
  }

  reset(): void {
    this.failures = 0;
    this.successCount = 0;
    this.lastFailureTime = null;
    this.state = 'CLOSED';
  }
}

/**
 * Not found handler for undefined routes
 */
export const notFoundHandler = (req: Request, res: Response, next: NextFunction): void => {
  const error = new NotFoundError(`Route ${req.method} ${req.path} not found`);
  next(error);
};

/**
 * Maintenance mode handler
 */
export const maintenanceHandler = (req: Request, res: Response, next: NextFunction): void => {
  if (process.env.MAINTENANCE_MODE === 'true') {
    const message = process.env.MAINTENANCE_MESSAGE || 'Service under maintenance';
    throw new ServiceUnavailableError(message);
  }
  next();
};

// Import AppDataSource for transaction wrapper
import { AppDataSource } from '@/config/database';

export default {
  globalErrorHandler,
  asyncHandler,
  tryCatchWrapper,
  withTransaction,
  retryOperation,
  CircuitBreaker,
  notFoundHandler,
  maintenanceHandler,
  // Export error classes
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  RateLimitError,
  ServiceUnavailableError
};
