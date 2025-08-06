import { AppDataSource } from '@/config/database';
import { logger } from '@/utils/logger';

export async function connectDatabase(): Promise<void> {
  try {
    if (!AppDataSource.isInitialized) {
      await AppDataSource.initialize();
      logger.info('🗄️  Database connected successfully');
      
      // Create default badges if they don't exist
      await createDefaultBadges();
    }
  } catch (error) {
    logger.error('❌ Database connection failed:', error);
    throw error;
  }
}

async function createDefaultBadges(): Promise<void> {
  try {
    const { Badge } = await import('@/models/Badge');
    const badgeRepository = AppDataSource.getRepository(Badge);
    
    const existingBadges = await badgeRepository.count();
    if (existingBadges > 0) {
      logger.info('📈 Default badges already exist');
      return;
    }

    const defaultBadges = [
      {
        name: 'First Task',
        description: 'Complete your first task',
        iconName: 'star.fill',
        color: 'blue',
        requirement: 1,
        type: 'task_completion'
      },
      {
        name: 'Task Master',
        description: 'Complete 10 tasks',
        iconName: 'crown.fill',
        color: 'gold',
        requirement: 10,
        type: 'task_completion'
      },
      {
        name: 'Point Collector',
        description: 'Earn 100 points',
        iconName: 'diamond.fill',
        color: 'purple',
        requirement: 100,
        type: 'points_earned'
      },
      {
        name: 'Team Player',
        description: 'Join a household',
        iconName: 'person.3.fill',
        color: 'green',
        requirement: 1,
        type: 'household_join'
      },
      {
        name: 'Streak Champion',
        description: 'Complete tasks for 7 consecutive days',
        iconName: 'flame.fill',
        color: 'orange',
        requirement: 7,
        type: 'streak'
      }
    ];

    for (const badgeData of defaultBadges) {
      const badge = badgeRepository.create(badgeData as any);
      await badgeRepository.save(badge);
    }

    logger.info('🏆 Default badges created successfully');
  } catch (error) {
    logger.error('Failed to create default badges:', error);
  }
}

export async function disconnectDatabase(): Promise<void> {
  try {
    if (AppDataSource.isInitialized) {
      await AppDataSource.destroy();
      logger.info('🗄️  Database disconnected');
    }
  } catch (error) {
    logger.error('❌ Database disconnection failed:', error);
  }
}
