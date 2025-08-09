import request from 'supertest';
import { Express } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { Household } from '@/models/Household';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { Reward } from '@/models/Reward';
import { RewardRedemption } from '@/models/RewardRedemption';
import { createTestApp } from '../createTestApp';
import { generateTestJWT } from '../utils/jwt';

describe('RewardController', () => {
  let app: Express;
  let userRepository = AppDataSource.getRepository(User);
  let householdRepository = AppDataSource.getRepository(Household);
  let membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  let rewardRepository = AppDataSource.getRepository(Reward);
  let redemptionRepository = AppDataSource.getRepository(RewardRedemption);

  let user: User;
  let household: Household;
  let token: string;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.DB_TYPE = 'sqlite';
    app = await createTestApp();
    userRepository = AppDataSource.getRepository(User);
    householdRepository = AppDataSource.getRepository(Household);
    membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
    rewardRepository = AppDataSource.getRepository(Reward);
    redemptionRepository = AppDataSource.getRepository(RewardRedemption);

    user = userRepository.create({
      name: 'Reward User',
      email: 'reward@example.com',
      hashedPassword: 'pwd',
      points: 100,
      avatarColor: 'blue'
    });
    await userRepository.save(user);
    token = generateTestJWT(user);

    household = householdRepository.create({
      name: 'Reward Household',
      inviteCode: 'REWARD01',
      createdBy: user.id
    });
    await householdRepository.save(household);

    const membership = membershipRepository.create({
      user,
      household,
      role: 'admin',
      isActive: true,
      joinedAt: new Date()
    });
    await membershipRepository.save(membership);
  });

  beforeEach(async () => {
    await redemptionRepository.createQueryBuilder().delete().from('reward_redemptions').execute();
    await rewardRepository.createQueryBuilder().delete().from('rewards').execute();
  });

  afterAll(async () => {
    await redemptionRepository.createQueryBuilder().delete().from('reward_redemptions').execute();
    await rewardRepository.createQueryBuilder().delete().from('rewards').execute();
    await membershipRepository.createQueryBuilder().delete().from('user_household_memberships').execute();
    await householdRepository.createQueryBuilder().delete().from('households').execute();
    await userRepository.createQueryBuilder().delete().from('users').execute();
  });

  it('lists rewards for a household', async () => {
    // Create two rewards
    const reward1: Reward = rewardRepository.create({
      name: 'Coffee', cost: 10, iconName: 'cup', color: 'brown', createdBy: user.id, household, creator: user
    } as any) as any;
    const reward2: Reward = rewardRepository.create({
      name: 'Movie', cost: 25, iconName: 'film', color: 'blue', createdBy: user.id, household, creator: user
    } as any) as any;
    await rewardRepository.save(reward1 as any);
    await rewardRepository.save(reward2 as any);

    const res = await request(app)
      .get(`/api/rewards/household/${household.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBe(2);
  });

  it('redeems a reward and emits event', async () => {
    const reward: Reward = rewardRepository.create({
      name: 'Gift Card', cost: 30, createdBy: user.id, household, creator: user
    } as any) as any;
    const saved = await rewardRepository.save(reward as any);
    const rewardId = (saved as any).id as string;

    const res = await request(app)
      .post(`/api/rewards/${rewardId}/redeem`)
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.data.reward.id).toBe(rewardId);
    // Ensure redemption created
    const count = await redemptionRepository.count({ where: { reward: { id: rewardId }, redeemedBy: { id: user.id } } as any });
    expect(count).toBe(1);
  });
});


