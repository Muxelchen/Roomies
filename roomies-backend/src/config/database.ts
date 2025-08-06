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

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://localhost:5432/roomies_dev';

export const AppDataSource = new DataSource({
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
});
