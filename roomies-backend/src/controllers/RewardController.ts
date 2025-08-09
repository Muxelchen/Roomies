import { Request, Response } from 'express';

import { AppDataSource } from '@/config/database';
import { createResponse, createErrorResponse, asyncHandler, ValidationError } from '@/middleware/errorHandler';
import { Reward } from '@/models/Reward';
import { RewardRedemption } from '@/models/RewardRedemption';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { logger } from '@/utils/logger';

export class RewardController {
  private rewardRepository = AppDataSource.getRepository(Reward);
  private redemptionRepository = AppDataSource.getRepository(RewardRedemption);
  private userRepository = AppDataSource.getRepository(User);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);

  /**
   * List rewards available in a household
   */
  listHouseholdRewards = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { householdId } = req.params;

    if (!req.user || !req.userId) {
      throw new ValidationError('User not authenticated');
    }

    // Verify membership
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: householdId }, isActive: true },
    });
    if (!membership) {
      throw new ValidationError('Access denied: not a household member');
    }

    const rewards = await this.rewardRepository.find({
      where: { household: { id: householdId }, isAvailable: true },
      relations: ['household', 'creator'],
      order: { cost: 'ASC', createdAt: 'DESC' },
    });

    res.json(createResponse(
      rewards.map(r => ({
        id: r.id,
        name: r.name,
        description: r.description,
        cost: r.cost,
        isAvailable: r.isAvailable,
        iconName: r.iconName,
        color: r.color,
        quantityAvailable: r.quantityAvailable,
        timesRedeemed: r.timesRedeemed,
        maxPerUser: r.maxPerUser,
        expiresAt: r.expiresAt,
        createdAt: r.createdAt,
      })),
      'Rewards fetched'
    ));
  });

  /**
   * Redeem a reward
   */
  redeemReward = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { rewardId } = req.params;

    if (!req.user || !req.userId) {
      throw new ValidationError('User not authenticated');
    }

    // Load reward with relations
    const reward = await this.rewardRepository.findOne({
      where: { id: rewardId },
      relations: ['household', 'creator', 'redemptions'],
    });

    if (!reward) {
      res.status(404).json(createErrorResponse('Reward not found', 'REWARD_NOT_FOUND'));
      return;
    }

    // Verify membership in the reward household
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: reward.household.id }, isActive: true },
      relations: ['user'],
    });

    if (!membership) {
      res.status(403).json(createErrorResponse('Access denied: not a household member', 'ACCESS_DENIED'));
      return;
    }

    const user = membership.user;

    // Business checks
    if (!reward.canBeRedeemed) {
      res.status(409).json(createErrorResponse('Reward is not available', 'REWARD_UNAVAILABLE'));
      return;
    }

    if (!reward.canUserRedeem(user)) {
      res.status(409).json(createErrorResponse('Insufficient points or limit reached', 'CANNOT_REDEEM'));
      return;
    }

    // Perform redemption
    try {
      const redemption = reward.redeem(user);
      redemption.redeemedAt = new Date();

      await this.userRepository.save(user); // points deducted within redeem()
      await this.rewardRepository.save(reward); // timesRedeemed updated
      await this.redemptionRepository.save(redemption);

      logger.info('Reward redeemed', { rewardId: reward.id, userId: user.id });

      // Emit WebSocket/SSE events to the household room
      try {
        const io = req.app.get('io');
        const payload = {
          redemptionId: redemption.id,
          reward: { id: reward.id, name: reward.name, cost: reward.cost },
          user: { id: user.id, name: user.name, avatarColor: user.avatarColor },
          householdId: reward.household.id,
          redeemedAt: redemption.redeemedAt,
          newUserPoints: user.points
        };
        if (io) {
          io.to(`household:${reward.household.id}`).emit('reward_redeemed', payload);
        }
        try {
          const { eventBroker } = require('@/services/EventBroker');
          eventBroker.broadcast(reward.household.id, 'reward_redeemed', payload);
        } catch (e) {
          logger.warn('SSE broadcast failed (continuing):', e);
        }
      } catch (e) {
        logger.warn('Reward redemption event emission failed (continuing):', e);
      }

      res.status(201).json(createResponse({
        id: redemption.id,
        reward: {
          id: reward.id,
          name: reward.name,
          cost: reward.cost,
        },
        pointsSpent: redemption.pointsSpent,
        redeemedAt: redemption.redeemedAt,
      }, 'Reward redeemed successfully'));
    } catch (error) {
      logger.error('Reward redemption failed', error as any);
      res.status(500).json(createErrorResponse('Failed to redeem reward', 'REDEEM_ERROR'));
    }
  });

  /**
   * Create a reward (household admin only)
   */
  createReward = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { name, description, cost, iconName, color, quantityAvailable, maxPerUser, expiresAt, householdId } = req.body || {};

    if (!req.userId) {
      res.status(401).json(createErrorResponse('User not authenticated', 'NOT_AUTHENTICATED'));
      return;
    }

    if (!name || !householdId || !cost) {
      res.status(400).json(createErrorResponse('name, cost, and householdId are required', 'VALIDATION_ERROR'));
      return;
    }

    const membership = await this.membershipRepository.findOne({ where: { user: { id: req.userId }, household: { id: householdId }, isActive: true } });
    if (!membership || membership.role !== 'admin') {
      res.status(403).json(createErrorResponse('Only household admins can create rewards', 'INSUFFICIENT_PERMISSIONS'));
      return;
    }

    const household = membership.household;
    const creator = membership.user;

    const reward = this.rewardRepository.create({
      name: String(name).trim(),
      description: description ? String(description).trim() : undefined,
      cost: Math.max(1, parseInt(String(cost), 10) || 1),
      isAvailable: true,
      iconName: iconName || 'gift',
      color: color || 'blue',
      quantityAvailable: quantityAvailable !== undefined && quantityAvailable !== null ? Number(quantityAvailable) : undefined,
      maxPerUser: maxPerUser !== undefined && maxPerUser !== null ? Number(maxPerUser) : undefined,
      expiresAt: expiresAt ? new Date(expiresAt) : undefined,
      createdBy: req.userId,
      household,
      creator
    });

    const saved = await this.rewardRepository.save(reward);

    res.status(201).json(createResponse({
      id: saved.id,
      name: saved.name,
      description: saved.description,
      cost: saved.cost,
      status: saved.status,
      iconName: saved.iconName,
      color: saved.color,
      quantityAvailable: saved.quantityAvailable ?? null,
      remainingQuantity: saved.remainingQuantity,
      maxPerUser: saved.maxPerUser ?? null,
      expiresAt: saved.expiresAt ?? null,
      householdId: saved.household.id,
      createdAt: saved.createdAt,
    }, 'Reward created'));
  });

  /**
   * Update a reward (household admin only)
   */
  updateReward = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { rewardId } = req.params;
    const { name, description, cost, iconName, color, quantityAvailable, maxPerUser, expiresAt, isAvailable } = req.body || {};

    if (!req.userId) {
      res.status(401).json(createErrorResponse('User not authenticated', 'NOT_AUTHENTICATED'));
      return;
    }

    const reward = await this.rewardRepository.findOne({ where: { id: rewardId }, relations: ['household'] });
    if (!reward) {
      res.status(404).json(createErrorResponse('Reward not found', 'REWARD_NOT_FOUND'));
      return;
    }

    const membership = await this.membershipRepository.findOne({ where: { user: { id: req.userId }, household: { id: reward.household.id }, isActive: true } });
    if (!membership || membership.role !== 'admin') {
      res.status(403).json(createErrorResponse('Only household admins can update rewards', 'INSUFFICIENT_PERMISSIONS'));
      return;
    }

    if (name !== undefined) reward.name = String(name).trim();
    if (description !== undefined) reward.description = String(description).trim();
    if (cost !== undefined) reward.cost = Math.max(1, parseInt(String(cost), 10) || reward.cost);
    if (iconName !== undefined) reward.iconName = String(iconName);
    if (color !== undefined) reward.color = String(color);
    if (quantityAvailable !== undefined) reward.updateQuantity(quantityAvailable === null ? null : Number(quantityAvailable));
    if (maxPerUser !== undefined) reward.maxPerUser = maxPerUser === null ? undefined : Number(maxPerUser);
    if (expiresAt !== undefined) reward.updateExpiration(expiresAt ? new Date(expiresAt) : null);
    if (isAvailable !== undefined) reward.isAvailable = Boolean(isAvailable);

    const saved = await this.rewardRepository.save(reward);

    res.json(createResponse({
      id: saved.id,
      name: saved.name,
      description: saved.description,
      cost: saved.cost,
      status: saved.status,
      iconName: saved.iconName,
      color: saved.color,
      quantityAvailable: saved.quantityAvailable ?? null,
      remainingQuantity: saved.remainingQuantity,
      maxPerUser: saved.maxPerUser ?? null,
      expiresAt: saved.expiresAt ?? null,
      updatedAt: saved.updatedAt
    }, 'Reward updated'));
  });

  /**
   * Delete a reward (household admin only)
   */
  deleteReward = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { rewardId } = req.params;
    if (!req.userId) {
      res.status(401).json(createErrorResponse('User not authenticated', 'NOT_AUTHENTICATED'));
      return;
    }

    const reward = await this.rewardRepository.findOne({ where: { id: rewardId }, relations: ['household'] });
    if (!reward) {
      res.status(404).json(createErrorResponse('Reward not found', 'REWARD_NOT_FOUND'));
      return;
    }

    const membership = await this.membershipRepository.findOne({ where: { user: { id: req.userId }, household: { id: reward.household.id }, isActive: true } });
    if (!membership || membership.role !== 'admin') {
      res.status(403).json(createErrorResponse('Only household admins can delete rewards', 'INSUFFICIENT_PERMISSIONS'));
      return;
    }

    await this.rewardRepository.delete(reward.id);
    res.json(createResponse({ id: reward.id }, 'Reward deleted'));
  });

  /**
   * Get current user's reward redemption history
   */
  getMyRedemptionHistory = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    if (!req.userId) {
      res.status(401).json(createErrorResponse('User not authenticated', 'NOT_AUTHENTICATED'));
      return;
    }

    const redemptions = await this.redemptionRepository.find({
      where: { redeemedBy: { id: req.userId } },
      relations: ['reward'],
      order: { redeemedAt: 'DESC' }
    });

    res.json(createResponse({
      history: redemptions.map(r => ({
        id: r.id,
        reward: { id: r.reward.id, name: r.reward.name, cost: r.reward.cost },
        pointsSpent: r.pointsSpent,
        redeemedAt: r.redeemedAt
      }))
    }, 'Reward redemption history'));
  });
}

export default RewardController;

