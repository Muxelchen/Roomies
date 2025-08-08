import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { Reward } from '@/models/Reward';
import { RewardRedemption } from '@/models/RewardRedemption';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { createResponse, createErrorResponse, asyncHandler, ValidationError } from '@/middleware/errorHandler';
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
}

export default RewardController;

