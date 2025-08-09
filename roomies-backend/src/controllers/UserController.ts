import { validate } from 'class-validator';
import { Request, Response } from 'express';

import { AppDataSource } from '@/config/database';
import { createResponse, createErrorResponse, asyncHandler } from '@/middleware/errorHandler';
import { Activity } from '@/models/Activity';
import { HouseholdTask } from '@/models/HouseholdTask';
import { RewardRedemption } from '@/models/RewardRedemption';
import { User } from '@/models/User';
import FileStorageService from '@/services/FileStorageService';
import { logger } from '@/utils/logger';

export class UserController {
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private activityRepository = AppDataSource.getRepository(Activity);
  private redemptionRepository = AppDataSource.getRepository(RewardRedemption);

  /**
   * Get current user profile with detailed information
   */
  getProfile = asyncHandler(async (req: Request, res: Response) => {
    try {
      if (!req.userId) {
        res.status(401).json(createErrorResponse(
          'User not authenticated',
          'NOT_AUTHENTICATED'
        ));
        return;
      }

      // Optimized user query with selective relations
      const userRepository = AppDataSource.getRepository(User);
      const user = await userRepository.findOne({
        where: { id: req.userId },
        relations: [
          'householdMemberships',
          'householdMemberships.household',
          'badges'
        ]
      });

      if (!user) {
        res.status(404).json(createErrorResponse(
          'User not found',
          'USER_NOT_FOUND'
        ));
        return;
      }

      // Get task statistics and recent activity in parallel
      let taskStats, recentActivities, rewardCount;
      try {
        [taskStats, recentActivities, rewardCount] = await Promise.all([
          this.getTaskStatistics(user.id),
          this.activityRepository.find({
            where: { user: { id: user.id } },
            order: { createdAt: 'DESC' },
            take: 10,
            relations: ['household']
          }),
          this.redemptionRepository.count({
            where: { redeemedBy: { id: user.id } }
          })
        ]);
      } catch (innerErr) {
        throw innerErr;
      }

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
        totalPoints: user.points,
        currentLevel: user.level,
        badgesEarned: user.badges?.length || 0,
        rewardsRedeemed: rewardCount,
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
    } catch (err) {
      logger.error('Failed to get profile', err as any);
      res.status(500).json(createErrorResponse('Failed to get profile', 'GET_PROFILE_ERROR'));
    }
  });

  /**
   * Update user profile
   */
  updateProfile = asyncHandler(async (req: Request, res: Response) => {
    if (!req.userId) {
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

    const userRepository = AppDataSource.getRepository(User);
    const user = await userRepository.findOne({
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

    await userRepository.save(user);

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
  });

  /**
   * Upload user avatar (expects base64 image or binary buffer in body)
   */
  uploadAvatar = asyncHandler(async (req: Request, res: Response) => {
    if (!req.userId) {
      res.status(401).json(createErrorResponse('User not authenticated', 'NOT_AUTHENTICATED'));
      return;
    }

    const { imageBase64, contentType } = req.body || {};
    if (!imageBase64 || !contentType || !contentType.startsWith('image/')) {
      res.status(400).json(createErrorResponse('imageBase64 and image/* contentType required', 'VALIDATION_ERROR'));
      return;
    }

    const buffer = Buffer.from(String(imageBase64), 'base64');
    const storage = FileStorageService.getInstance();
    const url = await storage.uploadAvatar(req.userId, buffer, contentType);

    const userRepository = AppDataSource.getRepository(User);
    const user = await userRepository.findOne({ where: { id: req.userId } });
    if (user) {
      (user as any).avatarUrl = url;
      await userRepository.save(user);
    }

    res.status(201).json(createResponse({ url }, 'Avatar uploaded'));
  });

  /**
   * Get user statistics
   */
  getStatistics = asyncHandler(async (req: Request, res: Response) => {
    try {
      if (!req.userId) {
        res.status(401).json(createErrorResponse(
          'User not authenticated',
          'NOT_AUTHENTICATED'
        ));
        return;
      }

      const userRepository = AppDataSource.getRepository(User);
      const user = await userRepository.findOne({
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

      // Get statistics in parallel for better performance
      let taskStats, rewardCount, weeklyActivities;
      try {
        [taskStats, rewardCount, weeklyActivities] = await Promise.all([
          this.getTaskStatistics(user.id),
          this.redemptionRepository.count({ where: { redeemedBy: { id: user.id } } }),
          this.activityRepository.find({
            where: { user: { id: user.id } },
            order: { createdAt: 'DESC' },
            take: 50 // Limit for performance
          })
        ]);
      } catch (innerErr) {
        throw innerErr;
      }

      const weeklyPoints = weeklyActivities.reduce((sum, activity) => sum + (activity.points || 0), 0);
      res.json(createResponse({
        overall: {
          totalPoints: user.points,
          currentLevel: user.level,
          currentStreak: user.streakDays,
          tasksCompleted: taskStats.completed,
          ...(taskStats.createdTotal >= 100 ? { tasksCreated: taskStats.createdTotal } : {}),
          badgesEarned: user.badges?.length || 0,
          rewardsRedeemed: rewardCount
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
    } catch (err) {
      logger.error('Failed to get statistics', err as any);
      res.status(500).json(createErrorResponse('Failed to get statistics', 'GET_STATISTICS_ERROR'));
    }
  });

  /**
   * Get user activity history with pagination
   */
  getActivityHistory = asyncHandler(async (req: Request, res: Response) => {
    if (!req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

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

    const pagination = {
      currentPage: page,
      totalPages: Math.ceil(total / limit),
      totalItems: total,
      hasNextPage: page * limit < total,
      hasPreviousPage: page > 1,
      itemsPerPage: limit
    };
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
      pagination
    }, undefined, pagination));
  });

  /**
   * Get user badges
   */
  getBadges = asyncHandler(async (req: Request, res: Response) => {
    if (!req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const userRepository = AppDataSource.getRepository(User);
    const user = await userRepository.findOne({
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
  });

  /**
   * Helper method to get task statistics for a user
   */
  private async getTaskStatistics(userId: string) {
    const completedTasks = await this.taskRepository.count({
      where: { assignedTo: { id: userId }, isCompleted: true }
    });

    // Scope created tasks to the user's active household when available
    let createdTasksTotal = 0;
    try {
      const membershipRepo = AppDataSource.getRepository('UserHouseholdMembership');
      const activeMembership: any = await membershipRepo.findOne({
        where: { user: { id: userId }, isActive: true },
        relations: ['household']
      });

      if (activeMembership?.household?.id) {
        createdTasksTotal = await this.taskRepository.count({
          where: { creator: { id: userId }, household: { id: activeMembership.household.id } }
        });
      } else {
        createdTasksTotal = await this.taskRepository.count({ where: { creator: { id: userId } } });
      }
    } catch {
      createdTasksTotal = await this.taskRepository.count({ where: { creator: { id: userId } } });
    }

    return {
      completed: completedTasks,
      createdTotal: createdTasksTotal
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
