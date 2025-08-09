import { AppDataSource } from '@/config/database';
import { createResponse, createErrorResponse, asyncHandler, ValidationError } from '@/middleware/errorHandler';
import { Challenge } from '@/models/Challenge';
import { User } from '@/models/User';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { logger } from '@/utils/logger';
import { Request, Response } from 'express';

export class ChallengeController {
  private challengeRepository = AppDataSource.getRepository(Challenge);
  private userRepository = AppDataSource.getRepository(User);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);

  /**
   * List active challenges in a household
   */
  listActive = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { householdId } = req.params;

    if (!req.user || !req.userId) {
      throw new ValidationError('User not authenticated');
    }

    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: householdId }, isActive: true },
    });
    if (!membership) {
      throw new ValidationError('Access denied: not a household member');
    }

    const challenges = await this.challengeRepository.find({
      where: { household: { id: householdId }, isActive: true },
      relations: ['participants', 'creator'],
      order: { createdAt: 'DESC' },
    });

    res.json(createResponse(challenges.map(c => ({
      id: c.id,
      title: c.title,
      description: c.description,
      pointReward: c.pointReward,
      isActive: c.isActive,
      dueDate: c.dueDate,
      maxParticipants: c.maxParticipants,
      completionCriteria: c.completionCriteria,
      iconName: c.iconName,
      color: c.color,
      participantCount: c.participantCount,
      createdAt: c.createdAt,
    })), 'Challenges fetched'));
  });

  /**
   * Join a challenge
   */
  join = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { challengeId } = req.params;

    if (!req.user || !req.userId) {
      throw new ValidationError('User not authenticated');
    }

    const challenge = await this.challengeRepository.findOne({
      where: { id: challengeId },
      relations: ['participants', 'household'],
    });

    if (!challenge) {
      res.status(404).json(createErrorResponse('Challenge not found', 'CHALLENGE_NOT_FOUND'));
      return;
    }

    // Verify membership
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: challenge.household.id }, isActive: true },
      relations: ['user'],
    });

    if (!membership) {
      res.status(403).json(createErrorResponse('Access denied: not a household member', 'ACCESS_DENIED'));
      return;
    }

    const user = membership.user;

    try {
      challenge.addParticipant(user);
      await this.challengeRepository.save(challenge);

      logger.info('User joined challenge', { challengeId: challenge.id, userId: user.id });

      // Emit WebSocket/SSE event to household participants
      try {
        const io = req.app.get('io');
        const payload = {
          challenge: { id: challenge.id, title: challenge.title },
          user: { id: user.id, name: user.name, avatarColor: user.avatarColor },
          householdId: challenge.household.id,
          participantCount: challenge.participantCount
        };
        if (io) {
          io.to(`household:${challenge.household.id}`).emit('challenge_joined', payload);
        }
        try {
          const { eventBroker } = require('@/services/EventBroker');
          eventBroker.broadcast(challenge.household.id, 'challenge_joined', payload);
        } catch (e) {
          logger.warn('SSE broadcast failed (continuing):', e);
        }
      } catch (e) {
        logger.warn('Challenge join event emission failed (continuing):', e);
      }

      res.json(createResponse({
        id: challenge.id,
        title: challenge.title,
        participantCount: challenge.participantCount,
      }, 'Joined challenge'));
    } catch (error) {
      res.status(409).json(createErrorResponse('Cannot join this challenge', 'CANNOT_JOIN'));
    }
  });
}

export default ChallengeController;

