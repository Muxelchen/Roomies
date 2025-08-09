import request from 'supertest';
import { Express } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { Household } from '@/models/Household';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { Challenge } from '@/models/Challenge';
import { createTestApp } from '../createTestApp';
import { generateTestJWT } from '../utils/jwt';

describe('ChallengeController', () => {
  let app: Express;
  let userRepository = AppDataSource.getRepository(User);
  let householdRepository = AppDataSource.getRepository(Household);
  let membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  let challengeRepository = AppDataSource.getRepository(Challenge);

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
    challengeRepository = AppDataSource.getRepository(Challenge);

    user = userRepository.create({ name: 'Challenger', email: 'ch@example.com', hashedPassword: 'pwd' });
    await userRepository.save(user);
    token = generateTestJWT(user);

    household = householdRepository.create({ name: 'Ch Household', inviteCode: 'CHALL001', createdBy: user.id });
    await householdRepository.save(household);

    const membership = membershipRepository.create({ user, household, role: 'member', isActive: true, joinedAt: new Date() });
    await membershipRepository.save(membership);
  });

  beforeEach(async () => {
    await challengeRepository.createQueryBuilder().delete().from('challenges').execute();
  });

  afterAll(async () => {
    await challengeRepository.createQueryBuilder().delete().from('challenges').execute();
    await membershipRepository.createQueryBuilder().delete().from('user_household_memberships').execute();
    await householdRepository.createQueryBuilder().delete().from('households').execute();
    await userRepository.createQueryBuilder().delete().from('users').execute();
  });

  it('lists active challenges for a household', async () => {
    const ch: Challenge = challengeRepository.create({
      title: 'Do 10 tasks',
      pointReward: 50,
      isActive: true,
      createdBy: user.id,
      household,
      creator: user
    } as any) as any;
    await challengeRepository.save(ch as any);

    const res = await request(app)
      .get(`/api/challenges/household/${household.id}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data[0].title).toBe('Do 10 tasks');
  });

  it('joins a challenge and returns updated count', async () => {
    const ch: Challenge = challengeRepository.create({
      title: 'Week Streak',
      pointReward: 20,
      isActive: true,
      createdBy: user.id,
      household,
      creator: user
    } as any) as any;
    await challengeRepository.save(ch as any);

    const res = await request(app)
      .post(`/api/challenges/${ch.id}/join`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data.id).toBe(ch.id);
    expect(res.body.data.participantCount).toBeGreaterThanOrEqual(1);
  });
});


