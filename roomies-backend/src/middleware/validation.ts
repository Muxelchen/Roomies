import Joi from 'joi';

import { ValidationError } from '@/middleware/errorHandler';
import { logger } from '@/utils/logger';
import { Request, Response, NextFunction } from 'express';

// Sanitize input to prevent XSS
function sanitizeString(input: any): string {
  if (typeof input !== 'string') return input;
  
  return input
    .trim()
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, '') // Remove script tags
    .replace(/<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>/gi, '') // Remove iframe tags
    .replace(/javascript:/gi, '') // Remove javascript: protocol
    .replace(/on\w+="[^"]*"/gi, '') // Remove event handlers
    .replace(/on\w+='[^']*'/gi, ''); // Remove event handlers with single quotes
}

function sanitizeObject(obj: any): any {
  if (obj === null || obj === undefined) return obj;
  
  if (typeof obj === 'string') {
    return sanitizeString(obj);
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeObject(item));
  }
  
  if (typeof obj === 'object') {
    const sanitized: any = {};
    for (const key in obj) {
      if (obj.hasOwnProperty(key)) {
        sanitized[key] = sanitizeObject(obj[key]);
      }
    }
    return sanitized;
  }
  
  return obj;
}

export function validateRequest(schema: Joi.Schema, target: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      // Sanitize input first
      if (target === 'body' && req.body) {
        req.body = sanitizeObject(req.body);
      } else if (target === 'query' && req.query) {
        req.query = sanitizeObject(req.query);
      } else if (target === 'params' && req.params) {
        req.params = sanitizeObject(req.params);
      }

      // Validate with Joi
      const { error, value } = schema.validate(req[target], {
        abortEarly: false, // Get all validation errors
        stripUnknown: true, // Remove unknown fields
        convert: true // Convert types where possible
      });

      if (error) {
        const validationErrors = error.details.map(detail => ({
          field: detail.path.join('.'),
          message: detail.message,
          value: detail.context?.value
        }));

        logger.warn('Validation failed', {
          url: req.url,
          method: req.method,
          errors: validationErrors,
          userId: req.userId
        });

        throw new ValidationError('Input validation failed', validationErrors);
      }

      // Replace the validated data
      req[target] = value;
      next();
    } catch (error) {
      next(error);
    }
  };
}

// Common validation schemas
export const schemas: { [k: string]: Joi.Schema } = {
  // Authentication
  register: Joi.object({
    email: Joi.string()
      .email({ tlds: { allow: false } })
      .required()
      .lowercase()
      .trim()
      .max(255)
      .messages({
        'string.email': 'Please provide a valid email address',
        'any.required': 'Email is required'
      }),
    password: Joi.string()
      .min(8)
      .max(128)
      .required()
      .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .messages({
        'string.min': 'Password must be at least 8 characters long',
        'string.pattern.base': 'Password must contain at least one lowercase letter, one uppercase letter, and one number',
        'any.required': 'Password is required'
      }),
    name: Joi.string()
      .min(2)
      .max(100)
      .required()
      .trim()
      .pattern(/^[a-zA-Z\s'-]+$/)
      .messages({
        'string.min': 'Name must be at least 2 characters long',
        'string.max': 'Name cannot exceed 100 characters',
        'string.pattern.base': 'Name can only contain letters, spaces, hyphens, and apostrophes',
        'any.required': 'Name is required'
      })
  }),

  login: Joi.object({
    email: Joi.string()
      .email({ tlds: { allow: false } })
      .required()
      .lowercase()
      .trim()
      .messages({
        'string.email': 'Please provide a valid email address',
        'any.required': 'Email is required'
      }),
    password: Joi.string()
      .required()
      .messages({
        'any.required': 'Password is required'
      })
  }),

  refreshToken: Joi.object({
    refreshToken: Joi.string()
      .required()
      .messages({
        'any.required': 'Refresh token is required'
      })
  }),

  changePassword: Joi.object({
    currentPassword: Joi.string()
      .required()
      .messages({
        'any.required': 'Current password is required'
      }),
    newPassword: Joi.string()
      .min(8)
      .max(128)
      .required()
      .pattern(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
      .messages({
        'string.min': 'New password must be at least 8 characters long',
        'string.pattern.base': 'New password must contain at least one lowercase letter, one uppercase letter, and one number',
        'any.required': 'New password is required'
      })
  }),

  forgotPassword: Joi.object({
    email: Joi.string()
      .email({ tlds: { allow: false } })
      .required()
      .lowercase()
      .trim()
      .messages({
        'string.email': 'Please provide a valid email address',
        'any.required': 'Email is required'
      })
  }),

  // Household
  createHousehold: Joi.object({
    name: Joi.string()
      .min(2)
      .max(100)
      .required()
      .trim()
      .messages({
        'string.min': 'Household name must be at least 2 characters long',
        'string.max': 'Household name cannot exceed 100 characters',
        'any.required': 'Household name is required'
      }),
    description: Joi.string()
      .max(500)
      .allow('')
      .trim()
      .messages({
        'string.max': 'Description cannot exceed 500 characters'
      })
  }),

  joinHousehold: Joi.object({
    inviteCode: Joi.string()
      .length(8)
      .alphanum()
      .required()
      .uppercase()
      .messages({
        'string.length': 'Invite code must be exactly 8 characters',
        'string.alphanum': 'Invite code can only contain letters and numbers',
        'any.required': 'Invite code is required'
      })
  }),

  // Task
  createTask: Joi.object({
    title: Joi.string()
      .min(1)
      .max(200)
      .required()
      .trim()
      .messages({
        'string.min': 'Task title cannot be empty',
        'string.max': 'Task title cannot exceed 200 characters',
        'any.required': 'Task title is required'
      }),
    description: Joi.string()
      .max(1000)
      .allow('')
      .trim()
      .messages({
        'string.max': 'Description cannot exceed 1000 characters'
      }),
    points: Joi.number()
      .integer()
      .min(1)
      .max(1000)
      .default(10)
      .messages({
        'number.min': 'Points must be at least 1',
        'number.max': 'Points cannot exceed 1000'
      }),
    priority: Joi.string()
      .valid('low', 'medium', 'high')
      .default('medium')
      .messages({
        'any.only': 'Priority must be low, medium, or high'
      }),
    dueDate: Joi.date()
      .iso()
      .messages({
        'date.format': 'Due date must be ISO formatted'
      }),
    isRecurring: Joi.boolean().default(false),
    recurringType: Joi.string()
      .valid('none', 'daily', 'weekly', 'monthly')
      .allow(null)
      .default('none'),
    assignedUserId: Joi.string()
      .uuid({ version: 'uuidv4' })
      .optional()
      .messages({ 'string.uuid': 'Invalid assigned user ID format' }),
    householdId: Joi.string()
      .uuid({ version: 'uuidv4' })
      .required()
      .messages({
        'string.uuid': 'Invalid household ID format',
        'any.required': 'Household ID is required'
      })
  }),

  // Update task (all fields optional; server enforces permissions)
  updateTask: Joi.object({
    title: Joi.string()
      .min(1)
      .max(200)
      .trim()
      .messages({
        'string.min': 'Task title cannot be empty',
        'string.max': 'Task title cannot exceed 200 characters'
      }),
    description: Joi.string()
      .max(1000)
      .allow('', null)
      .trim()
      .messages({ 'string.max': 'Description cannot exceed 1000 characters' }),
    points: Joi.number()
      .integer()
      .min(1)
      .max(1000)
      .messages({
        'number.min': 'Points must be at least 1',
        'number.max': 'Points cannot exceed 1000'
      }),
    priority: Joi.string()
      .valid('low', 'medium', 'high')
      .messages({ 'any.only': 'Priority must be low, medium, or high' }),
    dueDate: Joi.date().iso().allow(null).messages({ 'date.format': 'Due date must be ISO formatted' }),
    assignedUserId: Joi.string()
      .uuid({ version: 'uuidv4' })
      .allow(null, '')
      .messages({ 'string.uuid': 'Invalid assigned user ID format' })
  }),

  completeTask: Joi.object({
    proof: Joi.string()
      .max(500)
      .allow('')
      .trim()
      .messages({
        'string.max': 'Proof description cannot exceed 500 characters'
      }),
    imageUrl: Joi.string()
      .uri()
      .allow('')
      .messages({
        'string.uri': 'Image URL must be a valid URL'
      })
  }),

  

  // Common parameters
  uuid: Joi.string()
    .uuid({ version: 'uuidv4' })
    .required()
    .messages({
      'string.uuid': 'Invalid ID format',
      'any.required': 'ID is required'
    }),

  pagination: Joi.object({
    page: Joi.number()
      .integer()
      .min(1)
      .default(1)
      .messages({
        'number.min': 'Page must be at least 1'
      }),
    limit: Joi.number()
      .integer()
      .min(1)
      .max(100)
      .default(20)
      .messages({
        'number.min': 'Limit must be at least 1',
        'number.max': 'Limit cannot exceed 100'
      }),
    sortBy: Joi.string()
      .valid('createdAt', 'updatedAt', 'name', 'points', 'dueDate')
      .default('createdAt'),
    sortOrder: Joi.string()
      .valid('asc', 'desc')
      .default('desc')
  })
  ,

  // Comments
  taskComment: Joi.object({
    content: Joi.string()
      .min(1)
      .max(1000)
      .required()
      .trim()
      .messages({
        'string.min': 'Comment content cannot be empty',
        'string.max': 'Comment content cannot exceed 1000 characters',
        'any.required': 'Comment content is required'
      })
  })
};

// Helper function to validate UUID parameters
export function validateUUID(paramName: string = 'id') {
  return validateRequest(Joi.object({ [paramName]: schemas.uuid }), 'params');
}

// Helper function for pagination validation
export function validatePagination() {
  return validateRequest(schemas.pagination, 'query');
}

// Middleware to validate file uploads
export function validateFileUpload(allowedTypes: string[] = ['image/jpeg', 'image/png', 'image/gif'], maxSize: number = 5 * 1024 * 1024) {
  return (req: Request, res: Response, next: NextFunction) => {
    const file: any = (req as any).file;
    if (!file) {
      return next();
    }

    // Check file type
    if (!allowedTypes.includes(file.mimetype)) {
      throw new ValidationError(`File type not allowed. Allowed types: ${allowedTypes.join(', ')}`);
    }

    // Check file size
    if (file.size > maxSize) {
      throw new ValidationError(`File too large. Maximum size: ${maxSize / (1024 * 1024)}MB`);
    }

    next();
  };
}

// Rate limiting for specific operations
export function validateOperationFrequency(operationKey: string, maxOperations: number, windowMs: number) {
  const operations = new Map<string, { count: number; resetTime: number }>();

  return (req: Request, res: Response, next: NextFunction) => {
    const key = `${req.userId || req.ip}:${operationKey}`;
    const now = Date.now();
    const operation = operations.get(key);

    if (!operation || now > operation.resetTime) {
      // Reset or create new operation tracking
      operations.set(key, { count: 1, resetTime: now + windowMs });
      return next();
    }

    if (operation.count >= maxOperations) {
      throw new ValidationError(`Too many ${operationKey} operations. Please wait before trying again.`);
    }

    operation.count++;
    next();
  };
}
