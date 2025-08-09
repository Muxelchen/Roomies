import { Redis } from 'ioredis';

import { logger } from '@/utils/logger';

export interface CacheConfig {
  host: string;
  port: number;
  password?: string;
  db?: number;
  keyPrefix?: string;
  maxRetriesPerRequest?: number;
  lazyConnect?: boolean;
  connectTimeout?: number;
  commandTimeout?: number;
}

export interface CacheItem<T = any> {
  data: T;
  cachedAt: number;
  expiresAt: number;
}

export class CacheService {
  private redis: Redis | null = null;
  private isConnected = false;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private keyPrefix: string;

  constructor(config: CacheConfig) {
    this.keyPrefix = config.keyPrefix || 'roomies:';
    
    try {
      this.redis = new Redis({
        host: config.host,
        port: config.port,
        password: config.password,
        db: config.db || 0,
        keyPrefix: this.keyPrefix,
        maxRetriesPerRequest: config.maxRetriesPerRequest || 3,
        lazyConnect: config.lazyConnect !== false,
        connectTimeout: config.connectTimeout || 10000,
        commandTimeout: config.commandTimeout || 5000,
        reconnectOnError: (err) => {
          const targetError = 'READONLY';
          return err.message.includes(targetError);
        },
      });

      this.setupEventHandlers();
    } catch (error) {
      logger.error('Failed to initialize Redis client:', error);
    }
  }

  private setupEventHandlers(): void {
    if (!this.redis) return;

    this.redis.on('connect', () => {
      logger.info('Redis client connected');
      this.isConnected = true;
      this.reconnectAttempts = 0;
    });

    this.redis.on('ready', () => {
      logger.info('Redis client ready');
    });

    this.redis.on('error', (error) => {
      logger.error('Redis client error:', error);
      this.isConnected = false;
    });

    this.redis.on('close', () => {
      logger.warn('Redis client connection closed');
      this.isConnected = false;
    });

    this.redis.on('reconnecting', (delay) => {
      this.reconnectAttempts++;
      logger.info(`Redis client reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
      
      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        logger.error('Max Redis reconnection attempts reached');
        this.disconnect();
      }
    });
  }

  /**
   * Connect to Redis
   */
  async connect(): Promise<boolean> {
    if (!this.redis) {
      logger.error('Redis client not initialized');
      return false;
    }

    try {
      await this.redis.connect();
      this.isConnected = true;
      return true;
    } catch (error) {
      logger.error('Failed to connect to Redis:', error);
      this.isConnected = false;
      return false;
    }
  }

  /**
   * Disconnect from Redis
   */
  async disconnect(): Promise<void> {
    if (this.redis) {
      await this.redis.quit();
      this.redis = null;
      this.isConnected = false;
    }
  }

  /**
   * Check if Redis is available
   */
  isAvailable(): boolean {
    return this.redis !== null && this.isConnected;
  }

  /**
   * Set a value in cache with TTL
   */
  async set<T>(key: string, value: T, ttlSeconds = 3600): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const cacheItem: CacheItem<T> = {
        data: value,
        cachedAt: Date.now(),
        expiresAt: Date.now() + (ttlSeconds * 1000)
      };

      await this.redis!.setex(this.formatKey(key), ttlSeconds, JSON.stringify(cacheItem));
      return true;
    } catch (error) {
      logger.error(`Failed to set cache key ${key}:`, error);
      return false;
    }
  }

  /**
   * Get a value from cache
   */
  async get<T>(key: string): Promise<T | null> {
    if (!this.isAvailable()) {
      return null;
    }

    try {
      const cached = await this.redis!.get(this.formatKey(key));
      if (!cached) {
        return null;
      }

      const cacheItem: CacheItem<T> = JSON.parse(cached);
      
      // Check if cache has expired (additional safety check)
      if (cacheItem.expiresAt && Date.now() > cacheItem.expiresAt) {
        await this.delete(key);
        return null;
      }

      return cacheItem.data;
    } catch (error) {
      logger.error(`Failed to get cache key ${key}:`, error);
      return null;
    }
  }

  /**
   * Get multiple keys at once
   */
  async getMultiple<T>(keys: string[]): Promise<Record<string, T | null>> {
    if (!this.isAvailable() || keys.length === 0) {
      return {};
    }

    try {
      const formattedKeys = keys.map(key => this.formatKey(key));
      const values = await this.redis!.mget(...formattedKeys);
      
      const result: Record<string, T | null> = {};
      keys.forEach((originalKey, index) => {
        const cached = values[index];
        if (cached) {
          try {
            const cacheItem: CacheItem<T> = JSON.parse(cached);
            if (!cacheItem.expiresAt || Date.now() <= cacheItem.expiresAt) {
              result[originalKey] = cacheItem.data;
            } else {
              result[originalKey] = null;
              // Clean up expired key
              this.delete(originalKey).catch(err => 
                logger.error(`Failed to cleanup expired key ${originalKey}:`, err)
              );
            }
          } catch (parseError) {
            logger.error(`Failed to parse cached value for key ${originalKey}:`, parseError);
            result[originalKey] = null;
          }
        } else {
          result[originalKey] = null;
        }
      });

      return result;
    } catch (error) {
      logger.error('Failed to get multiple cache keys:', error);
      return {};
    }
  }

  /**
   * Delete a key from cache
   */
  async delete(key: string): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.del(this.formatKey(key));
      return result > 0;
    } catch (error) {
      logger.error(`Failed to delete cache key ${key}:`, error);
      return false;
    }
  }

  /**
   * Delete multiple keys
   */
  async deleteMultiple(keys: string[]): Promise<number> {
    if (!this.isAvailable() || keys.length === 0) {
      return 0;
    }

    try {
      const formattedKeys = keys.map(key => this.formatKey(key));
      return await this.redis!.del(...formattedKeys);
    } catch (error) {
      logger.error('Failed to delete multiple cache keys:', error);
      return 0;
    }
  }

  /**
   * Check if a key exists
   */
  async exists(key: string): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.exists(this.formatKey(key));
      return result === 1;
    } catch (error) {
      logger.error(`Failed to check existence of cache key ${key}:`, error);
      return false;
    }
  }

  /**
   * Set expiration for a key
   */
  async expire(key: string, ttlSeconds: number): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.expire(this.formatKey(key), ttlSeconds);
      return result === 1;
    } catch (error) {
      logger.error(`Failed to set expiration for cache key ${key}:`, error);
      return false;
    }
  }

  /**
   * Get TTL for a key
   */
  async ttl(key: string): Promise<number> {
    if (!this.isAvailable()) {
      return -1;
    }

    try {
      return await this.redis!.ttl(this.formatKey(key));
    } catch (error) {
      logger.error(`Failed to get TTL for cache key ${key}:`, error);
      return -1;
    }
  }

  /**
   * Increment a numeric value
   */
  async increment(key: string, by = 1): Promise<number | null> {
    if (!this.isAvailable()) {
      return null;
    }

    try {
      if (by === 1) {
        return await this.redis!.incr(this.formatKey(key));
      } else {
        return await this.redis!.incrby(this.formatKey(key), by);
      }
    } catch (error) {
      logger.error(`Failed to increment cache key ${key}:`, error);
      return null;
    }
  }

  /**
   * Add item to a set
   */
  async addToSet(key: string, member: string): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.sadd(this.formatKey(key), member);
      return result > 0;
    } catch (error) {
      logger.error(`Failed to add to set ${key}:`, error);
      return false;
    }
  }

  /**
   * Remove item from a set
   */
  async removeFromSet(key: string, member: string): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      const result = await this.redis!.srem(this.formatKey(key), member);
      return result > 0;
    } catch (error) {
      logger.error(`Failed to remove from set ${key}:`, error);
      return false;
    }
  }

  /**
   * Get all members of a set
   */
  async getSetMembers(key: string): Promise<string[]> {
    if (!this.isAvailable()) {
      return [];
    }

    try {
      return await this.redis!.smembers(this.formatKey(key));
    } catch (error) {
      logger.error(`Failed to get set members ${key}:`, error);
      return [];
    }
  }

  /**
   * Clear all cache (use with caution)
   */
  async clear(): Promise<boolean> {
    if (!this.isAvailable()) {
      return false;
    }

    try {
      await this.redis!.flushdb();
      logger.info('Cache cleared successfully');
      return true;
    } catch (error) {
      logger.error('Failed to clear cache:', error);
      return false;
    }
  }

  /**
   * Get cache statistics
   */
  async getStats(): Promise<{
    connected: boolean;
    usedMemory?: string;
    totalKeys?: number;
    hitRate?: string;
  }> {
    const stats = {
      connected: this.isConnected,
      usedMemory: undefined as string | undefined,
      totalKeys: undefined as number | undefined,
      hitRate: undefined as string | undefined,
    };

    if (!this.isAvailable()) {
      return stats;
    }

    try {
      const info = await this.redis!.info('memory');
      const memoryMatch = info.match(/used_memory_human:(.+)/);
      if (memoryMatch) {
        stats.usedMemory = memoryMatch[1].trim();
      }

      stats.totalKeys = await this.redis!.dbsize();

      // Get hit/miss statistics if available
      const statsInfo = await this.redis!.info('stats');
      const hitsMatch = statsInfo.match(/keyspace_hits:(\d+)/);
      const missesMatch = statsInfo.match(/keyspace_misses:(\d+)/);
      
      if (hitsMatch && missesMatch) {
        const hits = parseInt(hitsMatch[1]);
        const misses = parseInt(missesMatch[1]);
        const total = hits + misses;
        if (total > 0) {
          stats.hitRate = `${((hits / total) * 100).toFixed(2)}%`;
        }
      }
    } catch (error) {
      logger.error('Failed to get cache stats:', error);
    }

    return stats;
  }

  /**
   * Format cache key with prefix
   */
  private formatKey(key: string): string {
    // Key is already prefixed by Redis client, but we format for consistency
    return key;
  }

  /**
   * Cache warming utility - preload frequently accessed data
   */
  async warmCache(warmingFunctions: Array<() => Promise<void>>): Promise<void> {
    if (!this.isAvailable()) {
      logger.warn('Cache not available, skipping cache warming');
      return;
    }

    logger.info(`Starting cache warming with ${warmingFunctions.length} functions`);
    
    const results = await Promise.allSettled(warmingFunctions.map(fn => fn()));
    
    const successful = results.filter(r => r.status === 'fulfilled').length;
    const failed = results.filter(r => r.status === 'rejected').length;
    
    logger.info(`Cache warming completed: ${successful} successful, ${failed} failed`);
    
    if (failed > 0) {
      const errors = results
        .filter(r => r.status === 'rejected')
        .map(r => (r as PromiseRejectedResult).reason);
      logger.error('Cache warming errors:', errors);
    }
  }
}

// Singleton instance for application-wide use
let cacheServiceInstance: CacheService | null = null;

export function createCacheService(config: CacheConfig): CacheService {
  if (cacheServiceInstance) {
    logger.warn('Cache service already exists, returning existing instance');
    return cacheServiceInstance;
  }

  cacheServiceInstance = new CacheService(config);
  return cacheServiceInstance;
}

export function getCacheService(): CacheService | null {
  return cacheServiceInstance;
}

// Cache key generators for different data types
export const CacheKeys = {
  user: (userId: string) => `user:${userId}`,
  userProfile: (userId: string) => `user:profile:${userId}`,
  userStatistics: (userId: string) => `user:stats:${userId}`,
  userBadges: (userId: string) => `user:badges:${userId}`,
  household: (householdId: string) => `household:${householdId}`,
  householdMembers: (householdId: string) => `household:members:${householdId}`,
  householdTasks: (householdId: string) => `household:tasks:${householdId}`,
  tasksByUser: (userId: string) => `tasks:user:${userId}`,
  userActivities: (userId: string, page: number) => `activities:user:${userId}:page:${page}`,
  sessionData: (sessionId: string) => `session:${sessionId}`,
  rateLimitKey: (identifier: string, action: string) => `ratelimit:${action}:${identifier}`,
  leaderboard: (householdId: string) => `leaderboard:${householdId}`,
} as const;
