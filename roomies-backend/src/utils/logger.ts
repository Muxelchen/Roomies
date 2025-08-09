import winston from 'winston';
import fs from 'fs';
import path from 'path';

// Ensure logs directory exists to avoid file transport errors
try {
  const logsDir = path.join(process.cwd(), 'logs');
  if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
  }
} catch {
  // If we cannot create the directory, winston will fail file transports but console still works
}

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.json()
);

const consoleFormat = winston.format.combine(
  winston.format.colorize(),
  winston.format.timestamp({ format: 'HH:mm:ss' }),
  winston.format.printf(({ timestamp, level, message, stack, ...meta }) => {
    let log = `${timestamp} [${level}]: ${message}`;
    
    if (Object.keys(meta).length > 0) {
      log += ` ${JSON.stringify(meta)}`;
    }
    
    if (stack) {
      log += `\n${stack}`;
    }
    
    return log;
  })
);

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: logFormat,
  defaultMeta: { service: 'roomies-backend' },
  transports: [
    new winston.transports.File({
      filename: 'logs/error.log',
      level: 'error',
      maxsize: 10485760, // 10MB
      maxFiles: 5
    }),
    new winston.transports.File({
      filename: 'logs/combined.log',
      maxsize: 10485760, // 10MB
      maxFiles: 10
    })
  ]
});

// Add console logging in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(
    new winston.transports.Console({
      format: consoleFormat
    })
  );
}

// Cloud sync logging helpers
export const cloudLogger = {
  syncAttempt: (entity: string, action: string) => {
    logger.info('CloudKit sync attempt', { 
      entity, 
      action, 
      cloudSyncEnabled: process.env.CLOUDKIT_ENABLED === 'true'
    });
  },
  
  syncSuccess: (entity: string, action: string) => {
    logger.info('CloudKit sync successful', { entity, action });
  },
  
  syncSkipped: (entity: string, reason: string) => {
    logger.debug('CloudKit sync skipped', { entity, reason });
  },
  
  syncError: (entity: string, error: any) => {
    logger.error('CloudKit sync failed', { 
      entity, 
      error: error.message,
      stack: error.stack 
    });
  }
};

export default logger;
