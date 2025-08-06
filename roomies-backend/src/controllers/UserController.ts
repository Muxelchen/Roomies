import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { HouseholdTask } from '@/models/HouseholdTask';
import { Activity } from '@/models/Activity';
import { RewardRedemption } from '@/models/RewardRedemption';
import { logger } from '@/utils/logger';
import { createResponse, createErrorResponse } from '@/middleware/errorHandler';
import { validate } from 'class-validator';

export class UserController {
  private userRepository = AppDataSource.getRepository(User);
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private activityRepository = AppDataSource.getRepository(Activity);
  private redemptionRepository = AppDataSource.getRepository(RewardRedemption);

  /**
   * Get current user profile with detailed information
   */
  async getProfile(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const user = await this.userRepository.findOne({
        where: { id: req.userId },
        relations: [
          'householdMemberships',
          'householdMemberships.household',
          'badges',
          'rewardRedemptions',
          'rewardRedemptions.reward'
        ]
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      // Get task statistics
      const taskStats = await this.getTaskStatistics(user.id);
      
      // Get recent activity
      const recentActivities = await this.activityRepository.find({
        where: { user: { id: user.id } },
        order: { createdAt: 'DESC' },
        take: 10,
        relations: ['household']
      });

      const activeMembership = user.householdMemberships?.find(m => m.isActive);

      res.json(createResponse({
        id: user.id,
        name: user.name,
        email: user.email,
        avatarColor: user.avatarColor,
        points: user.points,
        level: user.level,
        streakDays: user.streakDays,
        lastActivity: user.lastActivity,
        createdAt: user.createdAt,
        household: activeMembership ? {
          id: activeMembership.household.id,
          name: activeMembership.household.name,
          role: activeMembership.role,
          joinedAt: activeMembership.joinedAt
        } : null,
        statistics: {
          totalTasksCompleted: taskStats.completed,
          totalTasksCreated: taskStats.created,
          totalPoints: user.points,
          currentLevel: user.level,
          badgesEarned: user.badges?.length || 0,
          rewardsRedeemed: user.rewardRedemptions?.length || 0,
          currentStreak: user.streakDays
        },
        badges: user.badges?.map(badge => ({
          id: badge.id,
          name: badge.name,
          description: badge.description,
          iconName: badge.iconName,
          color: badge.color,
          rarity: badge.rarity
        })) || [],
        recentActivity: recentActivities.map(activity => ({
          id: activity.id,
          type: activity.type,
          action: activity.action,
          points: activity.points,
          createdAt: activity.createdAt,
          household: activity.household ? {
            id: activity.household.id,
            name: activity.household.name
          } : null
        }))
      }));

    } catch (error) {
      logger.error('Get user profile failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get user profile',
        'GET_PROFILE_ERROR'
      ));
    }
  }

  /**
   * Update user profile
   */
  async updateProfile(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const { name, avatarColor } = req.body;

    // Validate input
    if (!name && !avatarColor) {
      res.status(400).json(createErrorResponse(
        'At least one field (name or avatarColor) is required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      const user = await this.userRepository.findOne({
        where: { id: req.userId }
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      // Update fields if provided
      if (name && name.trim().length >= 2) {
        user.name = name.trim();
      } else if (name) {
        res.status(400).json(createErrorResponse(
          'Name must be at least 2 characters long',
          'INVALID_NAME'
        ));
        return;
      }

      if (avatarColor) {
        const validColors = ['blue', 'green', 'orange', 'purple', 'red', 'teal', 'pink'];
        if (validColors.includes(avatarColor)) {
          user.avatarColor = avatarColor;
        } else {
          res.status(400).json(createErrorResponse(
            'Invalid avatar color',
            'INVALID_COLOR'
          ));
          return;
        }
      }

      // Validate entity
      const errors = await validate(user);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      await this.userRepository.save(user);

      logger.info('User profile updated', { userId: user.id });

      res.json(createResponse({
        id: user.id,
        name: user.name,
        email: user.email,
        avatarColor: user.avatarColor,
        points: user.points,
        level: user.level,
        streakDays: user.streakDays,
        updatedAt: user.updatedAt
      }, 'Profile updated successfully'));

    } catch (error) {
      logger.error('Update profile failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to update profile',
        'UPDATE_PROFILE_ERROR'
      ));
    }
  }

  /**
   * Get user statistics
   */
  async getStatistics(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const user = await this.userRepository.findOne({
        where: { id: req.userId },
        relations: ['badges', 'rewardRedemptions']
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      const taskStats = await this.getTaskStatistics(user.id);
      
      // Get weekly statistics
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);
      
      const weeklyActivities = await this.activityRepository.find({
        where: { 
          user: { id: user.id }
          // TODO: Add date filter when TypeORM date filtering is fixed
        }
      });

      const weeklyPoints = weeklyActivities.reduce((sum, activity) => sum + (activity.points || 0), 0);

      res.json(createResponse({
        overall: {
          totalPoints: user.points,
          currentLevel: user.level,
          currentStreak: user.streakDays,
          tasksCompleted: taskStats.completed,
          tasksCreated: taskStats.created,
          badgesEarned: user.badges?.length || 0,
          rewardsRedeemed: user.rewardRedemptions?.length || 0
        },
        thisWeek: {
          pointsEarned: weeklyPoints,
          tasksCompleted: weeklyActivities.filter(a => a.type === 'task_completed').length,
          activeDays: new Set(weeklyActivities.map(a => a.createdAt.toDateString())).size
        },
        streaks: {
          current: user.streakDays,
          best: user.streakDays, // TODO: Track best streak separately
          daysSinceLastTask: this.calculateDaysSinceLastTask(user.lastActivity)
        }
      }));

    } catch (error) {
      logger.error('Get user statistics failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get user statistics',
        'GET_STATISTICS_ERROR'
      ));
    }
  }

  /**
   * Get user activity history
   */
  async getActivityHistory(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const page = parseInt(req.query.page as string) || 1;
      const limit = Math.min(parseInt(req.query.limit as string) || 20, 100);
      const offset = (page - 1) * limit;

      const [activities, total] = await this.activityRepository.findAndCount({
        where: { user: { id: req.userId } },
        order: { createdAt: 'DESC' },
        take: limit,
        skip: offset,
        relations: ['household']
      });

      res.json(createResponse({
        activities: activities.map(activity => ({
          id: activity.id,
          type: activity.type,
          action: activity.action,
          points: activity.points,
          createdAt: activity.createdAt,
          household: activity.household ? {
            id: activity.household.id,
            name: activity.household.name
          } : null
        })),
        pagination: {
          currentPage: page,
          totalPages: Math.ceil(total / limit),
          totalItems: total,
          hasNextPage: page * limit < total,
          hasPreviousPage: page > 1
        }
      }));

    } catch (error) {
      logger.error('Get activity history failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get activity history',
        'GET_ACTIVITY_ERROR'
      ));
    }
  }

  /**
   * Get user badges
   */
  async getBadges(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const user = await this.userRepository.findOne({
        where: { id: req.userId },
        relations: ['badges']
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      res.json(createResponse({
        badges: user.badges?.map(badge => ({
          id: badge.id,
          name: badge.name,
          description: badge.description,
          iconName: badge.iconName,
          color: badge.color,
          rarity: badge.rarity,
          requirement: badge.requirement,
          type: badge.type,
          earnedAt: badge.createdAt
        })) || [],
        totalBadges: user.badges?.length || 0
      }));

    } catch (error) {
      logger.error('Get user badges failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get user badges',
        'GET_BADGES_ERROR'
      ));
    }
  }

  /**
   * Helper method to get task statistics for a user
   */
  private async getTaskStatistics(userId: string) {
    const completedTasks = await this.taskRepository.count({
      where: { 
        assignedTo: { id: userId },
        isCompleted: true 
      }
    });

    const createdTasks = await this.taskRepository.count({
      where: { createdBy: userId }
    });

    return {
      completed: completedTasks,
      created: createdTasks
    };
  }

  /**
   * Helper method to calculate days since last task
   */
  private calculateDaysSinceLastTask(lastActivity: Date | null): number {
    if (!lastActivity) return 0;
    
    const now = new Date();
    const diffTime = Math.abs(now.getTime() - lastActivity.getTime());
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  }
}
