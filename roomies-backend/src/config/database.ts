import { DataSource } from 'typeorm';
import { User } from '@/models/User';
import { Household } from '@/models/Household';
import { HouseholdTask } from '@/models/HouseholdTask';
import { Reward } from '@/models/Reward';
import { Challenge } from '@/models/Challenge';
import { Activity } from '@/models/Activity';
import { Badge } from '@/models/Badge';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { RewardRedemption } from '@/models/RewardRedemption';
import { TaskComment } from '@/models/TaskComment';
import { logger } from '@/utils/logger';
import { rdsConfig, isAWSEnabled } from '@/config/aws.config';

const isTestEnvironment = process.env.NODE_ENV === 'test' || process.env.DB_TYPE === 'sqlite';

// Use AWS RDS if enabled, otherwise fall back to local database
const getDatabaseUrl = (): string => {
  if (isTestEnvironment) {
    return '';
  }
  if (isAWSEnabled() && process.env.AWS_RDS_HOST) {
    const { username, password, host, port, database } = rdsConfig;
    return `postgresql://${username}:${password}@${host}:${port}/${database}`;
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
          TaskComment
        ],
        migrations: ['src/database/migrations/*.ts'],
        subscribers: ['src/database/subscribers/*.ts']
        // Note: Redis caching disabled for initial setup
      }
);
