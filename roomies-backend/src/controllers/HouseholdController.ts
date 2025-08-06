import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { Household } from '@/models/Household';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { HouseholdTask } from '@/models/HouseholdTask';
import { Activity } from '@/models/Activity';
import { logger } from '@/utils/logger';
import { createResponse, createErrorResponse } from '@/middleware/errorHandler';
import { validate } from 'class-validator';
import { CloudKitService } from '@/services/CloudKitService';

// CloudKit service will be initialized when needed
const getCloudKitService = () => {
  try {
    return new (require('@/services/CloudKitService').CloudKitService)();
  } catch {
    return null; // CloudKit not available
  }
};

export class HouseholdController {
  private householdRepository = AppDataSource.getRepository(Household);
  private userRepository = AppDataSource.getRepository(User);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private activityRepository = AppDataSource.getRepository(Activity);

  /**
   * Create a new household
   */
  async createHousehold(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const { name } = req.body;

    if (!name || name.trim().length < 2) {
      res.status(400).json(createErrorResponse(
        'Household name is required and must be at least 2 characters long',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      // Check if user is already part of an active household
      const existingMembership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, isActive: true }
      });

      if (existingMembership) {
        res.status(409).json(createErrorResponse(
          'User is already part of an active household',
          'ALREADY_IN_HOUSEHOLD'
        ));
        return;
      }

      // Create household
      const household = this.householdRepository.create({
        name: name.trim(),
        inviteCode: this.generateInviteCode(),
        createdBy: req.userId
      });

      const errors = await validate(household);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      const savedHousehold = await this.householdRepository.save(household);

      // Create membership for the creator as admin  
      const user = await this.userRepository.findOne({ where: { id: req.userId } });
      if (!user) throw new Error('User not found');
      
      const membership = this.membershipRepository.create({
        user: user,
        household: savedHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });

      await this.membershipRepository.save(membership);

      // Create activity
      await this.createActivity(
        req.userId,
        savedHousehold.id,
        'household_created',
        `Created household "${savedHousehold.name}"`,
        10 // Points for creating a household
      );

      // Sync to CloudKit if available
      try {
        const cloudKitService = getCloudKitService();
        if (cloudKitService) {
          await cloudKitService.syncHousehold(savedHousehold);
        }
      } catch (cloudError) {
        logger.warn('CloudKit sync failed for new household', cloudError);
      }

      logger.info('Household created', { householdId: savedHousehold.id, userId: req.userId });

      res.status(201).json(createResponse({
        id: savedHousehold.id,
        name: savedHousehold.name,
        inviteCode: savedHousehold.inviteCode,
        memberCount: 1,
        role: 'admin',
        createdAt: savedHousehold.createdAt
      }, 'Household created successfully'));

    } catch (error) {
      logger.error('Create household failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to create household',
        'CREATE_HOUSEHOLD_ERROR'
      ));
    }
  }

  /**
   * Join a household using invite code
   */
  async joinHousehold(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const { inviteCode } = req.body;

    if (!inviteCode || inviteCode.trim().length === 0) {
      res.status(400).json(createErrorResponse(
        'Invite code is required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      // Check if user is already part of an active household
      const existingMembership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, isActive: true }
      });

      if (existingMembership) {
        res.status(409).json(createErrorResponse(
          'User is already part of an active household',
          'ALREADY_IN_HOUSEHOLD'
        ));
        return;
      }

      // Find household by invite code
      const household = await this.householdRepository.findOne({
        where: { inviteCode: inviteCode.trim() },
        relations: ['memberships', 'memberships.user']
      });

      if (!household) {
        res.status(404).json(createErrorResponse(
          'Invalid invite code',
          'INVALID_INVITE_CODE'
        ));
        return;
      }

      // Check if user is already a member (even if inactive)
      const existingInactiveMembership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: household.id } }
      });

      if (existingInactiveMembership) {
        // Reactivate membership
        existingInactiveMembership.isActive = true;
        existingInactiveMembership.joinedAt = new Date();
        await this.membershipRepository.save(existingInactiveMembership);
      } else {
        // Create new membership
        const user = await this.userRepository.findOne({ where: { id: req.userId } });
        if (!user) throw new Error('User not found');
        
        const membership = this.membershipRepository.create({
          user: user,
          household: household,
          role: 'member',
          isActive: true,
          joinedAt: new Date()
        });
        await this.membershipRepository.save(membership);
      }

      // Create activity
      await this.createActivity(
        req.userId,
        household.id,
        'household_joined',
        `Joined household "${household.name}"`,
        5 // Points for joining a household
      );

      // Sync to CloudKit if available
      try {
        const cloudKitService = getCloudKitService();
        if (cloudKitService && req.user) {
          await cloudKitService.syncUser(req.user);
        }
      } catch (cloudError) {
        logger.warn('CloudKit sync failed for household join', cloudError);
      }

      // Emit WebSocket event to other household members
      const io = req.app.get('io');
      if (io) {
        io.to(`household:${household.id}`).emit('member_joined', {
          user: {
            id: req.user.id,
            name: req.user.name,
            avatarColor: req.user.avatarColor
          },
          joinedAt: new Date()
        });
      }

      logger.info('User joined household', { householdId: household.id, userId: req.userId });

      res.json(createResponse({
        id: household.id,
        name: household.name,
        memberCount: household.memberships.filter(m => m.isActive).length + 1,
        role: existingInactiveMembership ? existingInactiveMembership.role : 'member',
        joinedAt: new Date()
      }, 'Joined household successfully'));

    } catch (error) {
      logger.error('Join household failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to join household',
        'JOIN_HOUSEHOLD_ERROR'
      ));
    }
  }

  /**
   * Get current user's household
   */
  async getCurrentHousehold(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, isActive: true },
        relations: [
          'household',
          'household.memberships',
          'household.memberships.user',
          'household.tasks',
          'household.rewards',
          'household.challenges'
        ]
      });

      if (!membership) {
        res.json(createResponse(null, 'User is not part of any household'));
        return;
      }

      const household = membership.household;
      const activeMembers = household.memberships.filter(m => m.isActive);

      // Get household statistics
      const activeTasks = household.tasks?.filter(t => !t.isCompleted) || [];
      const completedTasks = household.tasks?.filter(t => t.isCompleted) || [];
      const activeRewards = household.rewards?.filter(r => r.isAvailable) || [];
      const activeChallenges = household.challenges?.filter(c => c.isActive) || [];

      res.json(createResponse({
        id: household.id,
        name: household.name,
        inviteCode: household.inviteCode,
        createdAt: household.createdAt,
        userRole: membership.role,
        joinedAt: membership.joinedAt,
        members: activeMembers.map(m => ({
          id: m.user.id,
          name: m.user.name,
          avatarColor: m.user.avatarColor,
          role: m.role,
          points: m.user.points,
          level: m.user.level,
          joinedAt: m.joinedAt,
          lastActivity: m.user.lastActivity
        })),
        statistics: {
          memberCount: activeMembers.length,
          activeTasks: activeTasks.length,
          completedTasks: completedTasks.length,
          availableRewards: activeRewards.length,
          activeChallenges: activeChallenges.length,
          totalPoints: activeMembers.reduce((sum, m) => sum + (m.user?.points || 0), 0)
        }
      }));

    } catch (error) {
      logger.error('Get current household failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get household information',
        'GET_HOUSEHOLD_ERROR'
      ));
    }
  }

  /**
   * Update household information (admin only)
   */
  async updateHousehold(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const { householdId } = req.params;
    const { name, description } = req.body;

    try {
      // Check if user is admin of the household
      const membership = await this.membershipRepository.findOne({
        where: { 
          user: { id: req.userId }, 
          household: { id: householdId },
          isActive: true 
        },
        relations: ['household']
      });

      if (!membership || membership.role !== 'admin') {
        res.status(403).json(createErrorResponse(
          'Only household admins can update household information',
          'INSUFFICIENT_PERMISSIONS'
        ));
        return;
      }

      const household = membership.household;

      // Update fields if provided
      if (name && name.trim().length >= 2) {
        household.name = name.trim();
      } else if (name) {
        res.status(400).json(createErrorResponse(
          'Household name must be at least 2 characters long',
          'INVALID_NAME'
        ));
        return;
      }


      const errors = await validate(household);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      await this.householdRepository.save(household);

      // Sync to CloudKit if available
      try {
        const cloudKitService = getCloudKitService();
        if (cloudKitService) {
          await cloudKitService.syncHousehold(household);
        }
      } catch (cloudError) {
        logger.warn('CloudKit sync failed for household update', cloudError);
      }

      // Emit WebSocket event to household members
      const io = req.app.get('io');
      if (io) {
        io.to(`household:${household.id}`).emit('household_updated', {
          id: household.id,
          name: household.name,
          updatedAt: household.updatedAt,
          updatedBy: req.user.name
        });
      }

      logger.info('Household updated', { householdId: household.id, userId: req.userId });

      res.json(createResponse({
        id: household.id,
        name: household.name,
        updatedAt: household.updatedAt
      }, 'Household updated successfully'));

    } catch (error) {
      logger.error('Update household failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to update household',
        'UPDATE_HOUSEHOLD_ERROR'
      ));
    }
  }

  /**
   * Leave household
   */
  async leaveHousehold(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, isActive: true },
        relations: ['household', 'household.memberships']
      });

      if (!membership) {
        res.status(404).json(createErrorResponse(
          'User is not part of any active household',
          'NOT_IN_HOUSEHOLD'
        ));
        return;
      }

      const household = membership.household;
      const activeMembers = household.memberships.filter(m => m.isActive);

      // Check if user is the only admin
      const admins = activeMembers.filter(m => m.role === 'admin');
      if (membership.role === 'admin' && admins.length === 1) {
        res.status(409).json(createErrorResponse(
          'Cannot leave household as the only admin. Transfer admin rights first or delete the household.',
          'LAST_ADMIN'
        ));
        return;
      }

      // Deactivate membership
      membership.isActive = false;
      await this.membershipRepository.save(membership);

      // Create activity
      await this.createActivity(
        req.userId,
        household.id,
        'household_left',
        `Left household "${household.name}"`,
        0
      );

      // Emit WebSocket event to remaining household members
      const io = req.app.get('io');
      if (io) {
        io.to(`household:${household.id}`).emit('member_left', {
          user: {
            id: req.user.id,
            name: req.user.name
          },
          leftAt: new Date()
        });
      }

      logger.info('User left household', { householdId: household.id, userId: req.userId });

      res.json(createResponse(
        {},
        'Left household successfully'
      ));

    } catch (error) {
      logger.error('Leave household failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to leave household',
        'LEAVE_HOUSEHOLD_ERROR'
      ));
    }
  }

  /**
   * Get household members
   */
  async getMembers(req: Request, res: Response): Promise<void> {
    const { householdId } = req.params;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      // Check if user is a member of this household
      const userMembership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: householdId }, isActive: true }
      });

      if (!userMembership) {
        res.status(403).json(createErrorResponse(
          'Access denied. User is not a member of this household.',
          'ACCESS_DENIED'
        ));
        return;
      }

      const memberships = await this.membershipRepository.find({
        where: { household: { id: householdId }, isActive: true },
        relations: ['user'],
        order: { joinedAt: 'ASC' }
      });

      res.json(createResponse({
        members: memberships.map(m => ({
          id: m.user.id,
          name: m.user.name,
          email: m.user.email,
          avatarColor: m.user.avatarColor,
          role: m.role,
          points: m.user.points,
          level: m.user.level,
          streakDays: m.user.streakDays,
          joinedAt: m.joinedAt,
          lastActivity: m.user.lastActivity
        })),
        totalMembers: memberships.length
      }));

    } catch (error) {
      logger.error('Get household members failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get household members',
        'GET_MEMBERS_ERROR'
      ));
    }
  }

  /**
   * Update member role (admin only)
   */
  async updateMemberRole(req: Request, res: Response): Promise<void> {
    const { householdId, memberId } = req.params;
    const { role } = req.body;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    if (!role || !['admin', 'member'].includes(role)) {
      res.status(400).json(createErrorResponse(
        'Invalid role. Must be either "admin" or "member"',
        'INVALID_ROLE'
      ));
      return;
    }

    try {
      // Check if current user is admin
      const adminMembership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: householdId }, isActive: true }
      });

      if (!adminMembership || adminMembership.role !== 'admin') {
        res.status(403).json(createErrorResponse(
          'Only household admins can update member roles',
          'INSUFFICIENT_PERMISSIONS'
        ));
        return;
      }

      // Find target member
      const targetMembership = await this.membershipRepository.findOne({
        where: { user: { id: memberId }, household: { id: householdId }, isActive: true },
        relations: ['user']
      });

      if (!targetMembership) {
        res.status(404).json(createErrorResponse(
          'Member not found in this household',
          'MEMBER_NOT_FOUND'
        ));
        return;
      }

      targetMembership.role = role;
      await this.membershipRepository.save(targetMembership);

      logger.info('Member role updated', { 
        householdId, 
        targetUserId: memberId, 
        newRole: role, 
        updatedBy: req.userId 
      });

      res.json(createResponse({
        memberId: memberId,
        newRole: role,
        updatedAt: new Date()
      }, `Member role updated to ${role}`));

    } catch (error) {
      logger.error('Update member role failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to update member role',
        'UPDATE_ROLE_ERROR'
      ));
    }
  }

  /**
   * Generate a unique invite code
   */
  private generateInviteCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  /**
   * Helper method to create activity records
   */
  private async createActivity(
    userId: string,
    householdId: string,
    type: string,
    action: string,
    points: number
  ): Promise<void> {
    try {
      const user = await this.userRepository.findOne({ where: { id: userId } });
      const household = await this.householdRepository.findOne({ where: { id: householdId } });
      
      if (!user || !household) {
        throw new Error('User or household not found for activity');
      }

      const activity = this.activityRepository.create({
        user: user,
        household: household,
        type: type as any,
        action,
        points
      });
      await this.activityRepository.save(activity);

      // Award points to user
      if (points > 0) {
        const user = await this.userRepository.findOne({ where: { id: userId } });
        if (user) {
          user.points += points;
          await this.userRepository.save(user);
        }
      }
    } catch (error) {
      logger.error('Failed to create activity:', error);
    }
  }
}
