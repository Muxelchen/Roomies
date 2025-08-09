import { DataSource } from 'typeorm';

import { Activity } from '@/models/Activity';
import { Badge } from '@/models/Badge';
import { Challenge } from '@/models/Challenge';
import { Household } from '@/models/Household';
import { HouseholdTask } from '@/models/HouseholdTask';
import { Reward } from '@/models/Reward';
import { RewardRedemption } from '@/models/RewardRedemption';
import { RefreshToken } from '@/models/RefreshToken';
import { TaskComment } from '@/models/TaskComment';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { logger } from '@/utils/logger';

const isTestEnvironment = process.env.NODE_ENV === 'test' || process.env.DB_TYPE === 'sqlite';

// Resolve database URL (local/dev by default)
const getDatabaseUrl = (): string => {
  if (isTestEnvironment) {
    return '';
  }
  return process.env.DATABASE_URL || 'postgresql://localhost:5432/roomies_dev';
};

const DATABASE_URL = getDatabaseUrl();

export const AppDataSource = new DataSource(
  isTestEnvironment
    ? {
        type: 'sqlite',
        database: ':memory:',
        synchronize: true,
        dropSchema: true,
        logging: false,
        entities: [
          User,
          Household,
          HouseholdTask,
          Reward,
          Challenge,
          Activity,
          Badge,
          UserHouseholdMembership,
          RewardRedemption,
          RefreshToken,
          TaskComment
        ],
        migrations: [],
        subscribers: []
      }
    : {
        type: 'postgres',
        url: DATABASE_URL,
        synchronize: process.env.NODE_ENV === 'development', // Auto-sync in development
        logging: process.env.NODE_ENV === 'development',
        entities: [
          User,
          Household,
          HouseholdTask,
          Reward,
          Challenge,
          Activity,
          Badge,
          UserHouseholdMembership,
          RewardRedemption,
          RefreshToken,
          TaskComment
        ],
        migrations: ['src/database/migrations/*.ts'],
        subscribers: ['src/database/subscribers/*.ts']
        // Note: Redis caching disabled for initial setup
      }
);
