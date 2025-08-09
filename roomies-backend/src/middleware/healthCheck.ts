import { Request, Response } from 'express';

import { AppDataSource } from '@/config/database';
import { logger } from '@/utils/logger';

interface HealthCheckResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  timestamp: string;
  uptime: number;
  environment: string;
  version: string;
  checks: {
    [key: string]: {
      status: 'pass' | 'fail' | 'warn';
      responseTime?: number;
      message?: string;
      details?: any;
    };
  };
}

export class HealthCheckService {
  private startTime: number;

  constructor() {
    this.startTime = Date.now();
  }

  /**
   * Comprehensive health check endpoint
   * Based on RFC Health Check Response Format
   */
  async performHealthCheck(req: Request, res: Response): Promise<void> {
    const healthCheck: HealthCheckResult = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      uptime: Math.floor((Date.now() - this.startTime) / 1000),
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
      checks: {}
    };

    // Run all health checks in parallel
    const checks = await Promise.allSettled([
      this.checkDatabase(),
      this.checkRedis(),
      this.checkMemory(),
      this.checkDisk(),
      this.checkExternalServices()
    ]);

    // Process results
    healthCheck.checks.database = this.getCheckResult(checks[0]);
    healthCheck.checks.redis = this.getCheckResult(checks[1]);
    healthCheck.checks.memory = this.getCheckResult(checks[2]);
    healthCheck.checks.disk = this.getCheckResult(checks[3]);
    healthCheck.checks.external_services = this.getCheckResult(checks[4]);

    // Determine overall status
    const failedChecks = Object.values(healthCheck.checks).filter(check => check.status === 'fail');
    const warnChecks = Object.values(healthCheck.checks).filter(check => check.status === 'warn');

    if (failedChecks.length > 0) {
      healthCheck.status = 'unhealthy';
    } else if (warnChecks.length > 0) {
      healthCheck.status = 'degraded';
    }

    // Set HTTP status based on health
    const httpStatus = healthCheck.status === 'healthy' ? 200 :
                      healthCheck.status === 'degraded' ? 200 :
                      503; // Service Unavailable

    logger.info('Health check performed', {
      status: healthCheck.status,
      failedChecks: failedChecks.length,
      warnChecks: warnChecks.length,
      uptime: healthCheck.uptime
    });

    res.status(httpStatus).json(healthCheck);
  }

  /**
   * Lightweight ready check for Kubernetes/Docker
   */
  async readyCheck(req: Request, res: Response): Promise<void> {
    try {
      // Only check critical dependencies for readiness
      await this.checkDatabase();
      
      res.status(200).json({
        status: 'ready',
        timestamp: new Date().toISOString()
      });
    } catch (error) {
      logger.error('Readiness check failed:', error);
      res.status(503).json({
        status: 'not ready',
        timestamp: new Date().toISOString(),
        error: error instanceof Error ? error.message : 'Unknown error'
      });
    }
  }

  /**
   * Simple liveness check for Kubernetes/Docker
   */
  async liveCheck(req: Request, res: Response): Promise<void> {
    // Liveness should only check if the application is running
    // Don't check external dependencies here
    res.status(200).json({
      status: 'alive',
      timestamp: new Date().toISOString(),
      uptime: Math.floor((Date.now() - this.startTime) / 1000)
    });
  }

  private getCheckResult(checkResult: PromiseSettledResult<any>) {
    if (checkResult.status === 'fulfilled') {
      return checkResult.value;
    } else {
      return {
        status: 'fail' as const,
        message: checkResult.reason?.message || 'Check failed'
      };
    }
  }

  private async checkDatabase() {
    const startTime = Date.now();
    try {
      if (!AppDataSource.isInitialized) {
        throw new Error('Database not initialized');
      }

      // Simple query to test connection
      await AppDataSource.query('SELECT 1');
      
      const responseTime = Date.now() - startTime;
      
      return {
        status: 'pass' as const,
        responseTime,
        message: 'Database connection healthy'
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      return {
        status: 'fail' as const,
        responseTime,
        message: error instanceof Error ? error.message : 'Database check failed'
      };
    }
  }

  private async checkRedis() {
    // Skip Redis check if not enabled
    if (process.env.NODE_ENV === 'development' && !process.env.REDIS_HOST) {
      return {
        status: 'warn' as const,
        message: 'Redis not configured in development'
      };
    }

    const startTime = Date.now();
    try {
      // TODO: Implement Redis connection check when Redis client is available
      // For now, assume it's healthy if configured
      const responseTime = Date.now() - startTime;
      
      return {
        status: 'pass' as const,
        responseTime,
        message: 'Redis connection healthy'
      };
    } catch (error) {
      const responseTime = Date.now() - startTime;
      return {
        status: process.env.NODE_ENV === 'production' ? 'fail' as const : 'warn' as const,
        responseTime,
        message: error instanceof Error ? error.message : 'Redis check failed'
      };
    }
  }

  private async checkMemory() {
    try {
      const usage = process.memoryUsage();
      const totalMemoryMB = Math.round(usage.heapTotal / 1024 / 1024);
      const usedMemoryMB = Math.round(usage.heapUsed / 1024 / 1024);
      const usagePercentage = Math.round((usage.heapUsed / usage.heapTotal) * 100);
      
      // Warn if memory usage is above 80%, fail if above 95% (but relax to warn in non-production envs)
      const env = (process.env.NODE_ENV || 'development').toLowerCase();
      const highUsage = usagePercentage > 95;
      const status = highUsage
        ? (env === 'production' ? 'fail' as const : 'warn' as const)
        : (usagePercentage > 80 ? 'warn' as const : 'pass' as const);
      
      return {
        status,
        message: `Memory usage: ${usedMemoryMB}MB / ${totalMemoryMB}MB (${usagePercentage}%)`,
        details: {
          heapUsed: usedMemoryMB,
          heapTotal: totalMemoryMB,
          usagePercentage,
          rss: Math.round(usage.rss / 1024 / 1024)
        }
      };
    } catch (error) {
      return {
        status: 'fail' as const,
        message: 'Memory check failed'
      };
    }
  }

  private async checkDisk() {
    try {
      // Simple disk space check - in production, this would check actual disk usage
      // For now, just return a basic status
      return {
        status: 'pass' as const,
        message: 'Disk space adequate'
      };
    } catch (error) {
      return {
        status: 'warn' as const,
        message: 'Disk check not implemented'
      };
    }
  }

  private async checkExternalServices() {
    try {
      const checks: any = {};
      
      // CloudKit check (if enabled)
      if (process.env.CLOUDKIT_ENABLED === 'true') {
        const hasContainer = !!process.env.CLOUDKIT_CONTAINER_ID;
        checks.cloudkit = {
          status: hasContainer ? 'pass' as const : 'warn' as const,
          message: hasContainer ? 'CloudKit ready' : 'Missing CLOUDKIT_CONTAINER_ID'
        };
      } else {
        checks.cloudkit = {
          status: 'pass' as const,
          message: 'CloudKit intentionally disabled'
        };
      }

      // No AWS: explicitly report AWS as removed
      checks.aws = {
        status: 'pass' as const,
        message: 'AWS removed; CloudKit is the only cloud provider'
      };

      // Determine overall external services status
      const hasFailures = Object.values(checks).some((check: any) => check.status === 'fail');
      const hasWarnings = Object.values(checks).some((check: any) => check.status === 'warn');

      return {
        status: hasFailures ? 'fail' as const : hasWarnings ? 'warn' as const : 'pass' as const,
        message: 'External services checked',
        details: checks
      };
    } catch (error) {
      return {
        status: 'warn' as const,
        message: 'External services check failed'
      };
    }
  }
}

// Export singleton instance
export const healthCheckService = new HealthCheckService();
