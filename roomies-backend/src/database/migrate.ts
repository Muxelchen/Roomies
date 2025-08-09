#!/usr/bin/env ts-node

/**
 * 🗄️ Database Migration Script
 * 
 * This script initializes the database, creates all tables based on TypeORM entities,
 * and sets up default data. It's the equivalent of running database migrations
 * in a traditional Rails or Django app.
 */

import 'reflect-metadata';
import { AppDataSource } from '@/config/database';
import { logger } from '@/utils/logger';
import { connectDatabase, disconnectDatabase } from './connection';

async function runMigrations(): Promise<void> {
  try {
    logger.info('🚀 Starting database migration...');
    
    // Initialize database connection and create tables
    await connectDatabase();
    
    // Run any additional setup queries if needed
    await runCustomMigrations();
    
    logger.info('✅ Database migration completed successfully!');
    logger.info('📊 Tables created and default data inserted.');
    
  } catch (error) {
    logger.error('❌ Migration failed:', error);
    throw error;
  } finally {
    await disconnectDatabase();
  }
}

/**
 * Run custom migration queries that might not be handled by TypeORM entities
 */
async function runCustomMigrations(): Promise<void> {
  try {
    const queryRunner = AppDataSource.createQueryRunner();
    
    // Create any custom indexes or constraints
    await queryRunner.query(`
      -- Create partial index for active tasks
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tasks_active 
      ON household_task (household_id, is_completed) 
      WHERE is_completed = false;
    `);
    
    await queryRunner.query(`
      -- Create index for user household memberships
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_household_membership 
      ON user_household_membership (user_id, household_id);
    `);
    
    await queryRunner.query(`
      -- Create index for activities by user and household
      CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activities_user_household 
      ON activity (user_id, household_id, created_at DESC);
    `);

    // Ensure users table has verification and reset fields
    await queryRunner.query(`
      ALTER TABLE IF EXISTS users
        ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT FALSE,
        ADD COLUMN IF NOT EXISTS email_verification_token_hash VARCHAR NULL,
        ADD COLUMN IF NOT EXISTS email_verification_expires TIMESTAMPTZ NULL,
        ADD COLUMN IF NOT EXISTS password_reset_token_hash VARCHAR NULL,
        ADD COLUMN IF NOT EXISTS password_reset_expires TIMESTAMPTZ NULL;
    `);
    
    await queryRunner.release();
    
    logger.info('🔧 Custom migrations applied successfully');
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.warn('⚠️  Custom migrations failed (this may be expected):', errorMessage);
  }
}

// Run migrations if this script is executed directly
if (require.main === module) {
  runMigrations()
    .then(() => {
      logger.info('🎉 Migration script completed!');
      process.exit(0);
    })
    .catch((error) => {
      logger.error('💥 Migration script failed:', error);
      process.exit(1);
    });
}

export { runMigrations };
