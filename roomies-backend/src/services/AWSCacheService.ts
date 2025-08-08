import Redis from 'ioredis';
import { elastiCacheConfig, isAWSEnabled } from '@/config/aws.config';
import { logger } from '@/utils/logger';

/**
 * AWS ElastiCache Service
 * Handles all caching operations with ElastiCache or local Redis fallback
 */
export class AWSCacheService {
  private static instance: AWSCacheService;
  private redis: Redis | null = null;
  private isConnected: boolean = false;

  private constructor() {
    this.connect();
  }

  public static getInstance(): AWSCacheService {
    if (!AWSCacheService.instance) {
      AWSCacheService.instance = new AWSCacheService();
    }
    return AWSCacheService.instance;
  }

  private async connect(): Promise<void> {
    try {
      const config = {
        host: elastiCacheConfig.host,
        port: elastiCacheConfig.port,
        password: elastiCacheConfig.password,
        retryStrategy: (times: number) => {
          const delay = Math.min(times * 50, 2000);
          return delay;
        },
        lazyConnect: true,
        enableOfflineQueue: true,
        maxRetriesPerRequest: 3
      };

      // Add TLS for production AWS ElastiCache
      if (isAWSEnabled() && process.env.NODE_ENV === 'production') {
        Object.assign(config, { tls: elastiCacheConfig.tls });
      }

      this.redis = new Redis(config);

      this.redis.on('connect', () => {
        this.isConnected = true;
        logger.info(`✅ Connected to ${isAWSEnabled() ? 'AWS ElastiCache' : 'Local Redis'}`);
      });

      this.redis.on('error', (error) => {
        logger.error('Redis connection error:', error);
        this.isConnected = false;
      });

      this.redis.on('close', () => {
        this.isConnected = false;
        logger.warn('Redis connection closed');
      });

      await this.redis.connect();
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      this.isConnected = false;
    }
  }

  /**
   * Check if cache is available
   */
  isAvailable(): boolean {
    return this.isConnected && this.redis !== null;
  }

  /**
   * Get value from cache
   */
  async get<T>(key: string): Promise<T | null> {
    if (!this.isAvailable()) {
      logger.debug(`Cache unavailable, skipping get for key: ${key}`);
      return null;
    }

    try {
      const value = await this.redis!.get(key);
      if (value) {
        return JSON.parse(value) as T;
      }
      return null;
    } catch (error) {
      logger.error(`Cache get error for key ${key}:`, error);
      return null;
    }
  }

  /**
   * Set value in cache
   */
  async set(key: string, value: any, ttlSeconds?: number): Promise<boolean> {
    if (!this.isAvailable()) {
      logger.debug(`Cache unavailable, skipping set for key: ${key}`);
      return false;
    }

    try {
      const serialized = JSON.stringify(value);
      
      if (ttlSeconds) {
        await this.redis!.setex(key, ttlSeconds, serialized);
      } else {
        await this.redis!.set(key, serialized);
      }
      
      return true;
    } catch (error) {
      logger.error(`Cache set error for key ${key}:`, error);
      return false;
    }
  }

  /**
   * Delete value from cache
   */
  async delete(key: string): Promise<boolean> {
    if (!this.isAvailable()) {
      logger.debug(`Cache unavailable, skipping delete for key: ${key}`);
      return false;
    }

    try {
      await this.redis!.del(key);
      return true;
    } catch (error) {
      logger.error(`Cache delete error for key ${key}:`, error);
      return false;
    }
  }

  /**
   * Delete multiple keys matching a pattern
   */
  async deletePattern(pattern: string): Promise<number> {
    if (!this.isAvailable()) {
      logger.debug(`Cache unavailable, skipping delete pattern: ${pattern}`);
      return 0;
    }

    try {
      const keys = await this.redis!.keys(pattern);
      if (keys.length > 0) {
        return await this.redis!.del(...keys);
      }
      return 0;
    } catch (error) {
      logger.error(`Cache delete pattern error for ${pattern}:`, error);
      return 0;
    }
  }

  /**
   * Check if key exists
   */
  async exists(key: string): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.exists(key);
      return result === 1;
    } catch (error) {
      logger.error(`Cache exists error for key ${key}:`, error);
      return false;
    }
  }

  /**
   * Get remaining TTL for a key
   */
  async ttl(key: string): Promise<number> {
    if (!this.isAvailable()) {
      return -1;
    }

    try {
      return await this.redis!.ttl(key);
    } catch (error) {
      logger.error(`Cache TTL error for key ${key}:`, error);
      return -1;
    }
  }

  /**
   * Increment a counter
   */
  async increment(key: string, amount: number = 1): Promise<number> {
    if (!this.isAvailable()) {
      return 0;
    }

    try {
      return await this.redis!.incrby(key, amount);
    } catch (error) {
      logger.error(`Cache increment error for key ${key}:`, error);
      return 0;
    }
  }

  /**
   * Add to a set
   */
  async addToSet(key: string, ...members: string[]): Promise<number> {
    if (!this.isAvailable()) {
      return 0;
    }

    try {
      return await this.redis!.sadd(key, ...members);
    } catch (error) {
      logger.error(`Cache add to set error for key ${key}:`, error);
      return 0;
    }
  }

  /**
   * Get set members
   */
  async getSetMembers(key: string): Promise<string[]> {
    if (!this.isAvailable()) {
      return [];
    }

    try {
      return await this.redis!.smembers(key);
    } catch (error) {
      logger.error(`Cache get set members error for key ${key}:`, error);
      return [];
    }
  }

  /**
   * Cache user session
   */
  async cacheUserSession(userId: string, sessionData: any, ttlHours: number = 24): Promise<boolean> {
    const key = `session:${userId}`;
    return await this.set(key, sessionData, ttlHours * 3600);
  }

  /**
   * Get user session
   */
  async getUserSession(userId: string): Promise<any> {
    const key = `session:${userId}`;
    return await this.get(key);
  }

  /**
   * Cache household data
   */
  async cacheHousehold(householdId: string, data: any, ttlMinutes: number = 30): Promise<boolean> {
    const key = `household:${householdId}`;
    return await this.set(key, data, ttlMinutes * 60);
  }

  /**
   * Get cached household
   */
  async getCachedHousehold(householdId: string): Promise<any> {
    const key = `household:${householdId}`;
    return await this.get(key);
  }

  /**
   * Invalidate household cache
   */
  async invalidateHouseholdCache(householdId: string): Promise<void> {
    await this.deletePattern(`household:${householdId}*`);
    await this.deletePattern(`tasks:household:${householdId}*`);
    await this.deletePattern(`members:household:${householdId}*`);
  }

  /**
   * Cache task list
   */
  async cacheTaskList(householdId: string, tasks: any[], ttlMinutes: number = 15): Promise<boolean> {
    const key = `tasks:household:${householdId}`;
    return await this.set(key, tasks, ttlMinutes * 60);
  }

  /**
   * Get cached task list
   */
  async getCachedTaskList(householdId: string): Promise<any[]> {
    const key = `tasks:household:${householdId}`;
    const tasks = await this.get<any[]>(key);
    return tasks || [];
  }

  /**
   * Rate limiting helper
   */
  async checkRateLimit(identifier: string, limit: number, windowSeconds: number): Promise<boolean> {
    if (!this.isAvailable()) {
      return true; // Allow if cache is unavailable
    }

    const key = `ratelimit:${identifier}`;
    const current = await this.increment(key);
    
    if (current === 1) {
      await this.redis!.expire(key, windowSeconds);
    }

    return current <= limit;
  }

  /**
   * Disconnect from Redis
   */
  async disconnect(): Promise<void> {
    if (this.redis) {
      await this.redis.quit();
      this.isConnected = false;
      logger.info('Disconnected from Redis');
    }
  }
}

export default AWSCacheService;
