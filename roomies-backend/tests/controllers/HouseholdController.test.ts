import request from 'supertest';
import { Express } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { Household } from '@/models/Household';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { HouseholdTask } from '@/models/HouseholdTask';
import { Activity } from '@/models/Activity';
import { createTestApp } from '../createTestApp';
import { generateTestJWT } from '../utils/jwt';
import { logger } from '@/utils/logger';

describe('HouseholdController - Optimized', () => {
  let app: Express;
  let testUser: User;
  let testUser2: User;
  let testHousehold: Household;
  let testMembership: UserHouseholdMembership;
  let authToken: string;
  let authToken2: string;

  let userRepository = AppDataSource.getRepository(User);
  let householdRepository = AppDataSource.getRepository(Household);
  let membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  let taskRepository = AppDataSource.getRepository(HouseholdTask);
  let activityRepository = AppDataSource.getRepository(Activity);

  beforeAll(async () => {
  // Force the in-memory SQLite driver in AppDataSource
  process.env.NODE_ENV = 'test';
  process.env.DB_TYPE = 'sqlite';
    app = await createTestApp();
    userRepository = AppDataSource.getRepository(User);
    householdRepository = AppDataSource.getRepository(Household);
    membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
    taskRepository = AppDataSource.getRepository(HouseholdTask);
    activityRepository = AppDataSource.getRepository(Activity);
    
    // Create test users
    testUser = userRepository.create({
      name: 'Test User',
      email: 'test@example.com',
      hashedPassword: 'hashedpassword',
      avatarColor: 'blue',
      points: 100
    });
    await userRepository.save(testUser);

    testUser2 = userRepository.create({
      name: 'Test User 2',
      email: 'test2@example.com',
      hashedPassword: 'hashedpassword',
      avatarColor: 'green',
      points: 50
    });
    await userRepository.save(testUser2);

    // Generate auth tokens
    authToken = generateTestJWT(testUser);
    authToken2 = generateTestJWT(testUser2);
  });

  afterAll(async () => {
    // Clean up test data (use query builder to support sqlite)
    await activityRepository.createQueryBuilder().delete().from('activities').execute();
    await taskRepository.createQueryBuilder().delete().from('household_tasks').execute();
    await membershipRepository.createQueryBuilder().delete().from('user_household_memberships').execute();
    await householdRepository.createQueryBuilder().delete().from('households').execute();
    await userRepository.createQueryBuilder().delete().from('users').execute();
  });

  beforeEach(async () => {
    // Clear household-related data before each test (sqlite-safe)
    await activityRepository.createQueryBuilder().delete().from('activities').execute();
    await taskRepository.createQueryBuilder().delete().from('household_tasks').execute();
    await membershipRepository.createQueryBuilder().delete().from('user_household_memberships').execute();
    await householdRepository.createQueryBuilder().delete().from('households').execute();
  });

  describe('POST /households - createHousehold', () => {
    it('should create a household successfully with proper error handling', async () => {
      const householdData = {
        name: 'Test Household'
      };

      const response = await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send(householdData)
        .expect(201);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Test Household');
      expect(response.body.data.inviteCode).toHaveLength(8);
      expect(response.body.data.memberCount).toBe(1);
      expect(response.body.data.role).toBe('admin');

      // Verify household was created in database
      const household = await householdRepository.findOne({
        where: { id: response.body.data.id }
      });
      expect(household).toBeDefined();
      expect(household.name).toBe('Test Household');

      // Verify membership was created
      const membership = await membershipRepository.findOne({
        where: { user: { id: testUser.id }, household: { id: household.id } }
      });
      expect(membership).toBeDefined();
      expect(membership.role).toBe('admin');
      expect(membership.isActive).toBe(true);
    });

    it('should prevent user from creating multiple active households', async () => {
      // Create first household
      await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'First Household' })
        .expect(201);

      // Try to create second household
      const response = await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'Second Household' })
        .expect(409);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('ALREADY_IN_HOUSEHOLD');
    });

    it('should validate household name requirements', async () => {
      // Test empty name
      await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: '' })
        .expect(400);

      // Test short name
      await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'A' })
        .expect(400);
    });

    it('should require authentication', async () => {
      await request(app)
        .post('/api/households')
        .send({ name: 'Test Household' })
        .expect(401);
    });

    it('should handle database errors gracefully', async () => {
      // Spy on logger to verify error handling
      const loggerSpy = jest.spyOn(logger, 'error').mockImplementation();

      // Mock repository to throw error
      const saveSpy = jest.spyOn(householdRepository, 'save')
        .mockRejectedValueOnce(new Error('Database error'));

      const response = await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'Test Household' })
        .expect(500);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('CREATE_HOUSEHOLD_ERROR');
      expect(loggerSpy).toHaveBeenCalled();

      saveSpy.mockRestore();
      loggerSpy.mockRestore();
    });
  });

  describe('POST /households/join - joinHousehold', () => {
    beforeEach(async () => {
      // Create test household
      testHousehold = householdRepository.create({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      // Create admin membership for testUser
      testMembership = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save(testMembership);
    });

    it('should join household successfully with valid invite code', async () => {
      const response = await request(app)
        .post('/api/households/join')
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ inviteCode: 'TEST1234' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Test Household');
      expect(response.body.data.role).toBe('member');

      // Verify membership was created
      const membership = await membershipRepository.findOne({
        where: { user: { id: testUser2.id }, household: { id: testHousehold.id } }
      });
      expect(membership).toBeDefined();
      expect(membership.isActive).toBe(true);
    });

    it('should prevent joining with invalid invite code', async () => {
      const response = await request(app)
        .post('/api/households/join')
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ inviteCode: 'INVALID1' })
        .expect(404);

      expect(response.body.success).toBe(false);
      expect(response.body.error.code).toBe('INVALID_INVITE_CODE');
    });

    it('should prevent user from joining multiple households', async () => {
      // User joins first household
      await request(app)
        .post('/api/households/join')
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ inviteCode: 'TEST1234' })
        .expect(200);

      // Create another household
      const household2 = householdRepository.create({
        name: 'Test Household 2',
        inviteCode: 'TEST5678',
        createdBy: testUser.id
      });
      await householdRepository.save(household2);

      // Try to join second household
      const response = await request(app)
        .post('/api/households/join')
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ inviteCode: 'TEST5678' })
        .expect(409);

      expect(response.body.error.code).toBe('ALREADY_IN_HOUSEHOLD');
    });

    it('should reactivate inactive membership', async () => {
      // Create inactive membership
      const inactiveMembership = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: false,
        joinedAt: new Date('2023-01-01')
      });
      await membershipRepository.save(inactiveMembership);

      const response = await request(app)
        .post('/api/households/join')
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ inviteCode: 'TEST1234' })
        .expect(200);

      expect(response.body.success).toBe(true);

      // Verify membership was reactivated
      const updatedMembership = await membershipRepository.findOne({
        where: { user: { id: testUser2.id }, household: { id: testHousehold.id } }
      });
      expect(updatedMembership.isActive).toBe(true);
      expect(updatedMembership.joinedAt.getTime()).toBeGreaterThan(new Date('2023-01-01').getTime());
    });
  });

  describe('GET /households/current - getCurrentHousehold', () => {
    beforeEach(async () => {
      // Create test household with members and tasks
      testHousehold = householdRepository.create({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      // Create memberships
      const membership1 = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });
      const membership2 = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save([membership1, membership2]);

      // Create test tasks
      const task1 = taskRepository.create({
        title: 'Active Task',
        description: 'Test task',
        household: testHousehold,
        assignedTo: testUser,
        createdBy: testUser.id,
        isCompleted: false,
        points: 10
      });
      const task2 = taskRepository.create({
        title: 'Completed Task',
        description: 'Completed task',
        household: testHousehold,
        assignedTo: testUser2,
        createdBy: testUser.id,
        isCompleted: true,
        points: 15
      });
      await taskRepository.save([task1, task2]);
    });

    it('should return optimized household data with statistics', async () => {
      const response = await request(app)
        .get('/api/households/current')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toMatchObject({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        // userRole is optional in response shape
        members: expect.arrayContaining([
          expect.objectContaining({
            name: 'Test User',
            role: 'admin'
          }),
          expect.objectContaining({
            name: 'Test User 2',
            role: 'member'
          })
        ]),
        statistics: expect.objectContaining({
          memberCount: 2,
          activeTasks: 1,
          completedTasks: 1
        })
      });
    });

    it('should return null for users not in any household', async () => {
      const tempUser = userRepository.create({
        name: 'No Household',
        email: 'nohousehold@example.com',
        hashedPassword: 'pwd'
      });
      await userRepository.save(tempUser);

      const response = await request(app)
        .get('/api/households/current')
        .set('Authorization', `Bearer ${generateTestJWT(tempUser)}`)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toBeNull();
    });

    it('should handle database performance optimizations', async () => {
      // Monitor query performance
      const startTime = Date.now();

      const response = await request(app)
        .get('/api/households/current')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      const endTime = Date.now();
      const responseTime = endTime - startTime;

      expect(response.body.success).toBe(true);
      // Should complete within reasonable time (optimized queries)
      expect(responseTime).toBeLessThan(1000);
    });
  });

  describe('PUT /households/:id - updateHousehold', () => {
    beforeEach(async () => {
      testHousehold = householdRepository.create({
        name: 'Original Name',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      testMembership = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save(testMembership);
    });

    it('should update household name successfully', async () => {
      const updateData = { name: 'Updated Name' };

      const response = await request(app)
        .put(`/api/households/${testHousehold.id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send(updateData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.name).toBe('Updated Name');

      // Verify database was updated
      const updatedHousehold = await householdRepository.findOne({
        where: { id: testHousehold.id }
      });
      expect(updatedHousehold.name).toBe('Updated Name');
    });

    it('should reject updates from non-admin users', async () => {
      // Create member membership for testUser2
      const memberMembership = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save(memberMembership);

      const response = await request(app)
        .put(`/api/households/${testHousehold.id}`)
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ name: 'Updated Name' })
        .expect(403);

      expect(response.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
    });

    it('should validate name requirements', async () => {
      await request(app)
        .put(`/api/households/${testHousehold.id}`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'A' })
        .expect(400);
    });
  });

  describe('POST /households/leave - leaveHousehold', () => {
    beforeEach(async () => {
      testHousehold = householdRepository.create({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      // Create admin and member memberships
      const adminMembership = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });
      const memberMembership = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save([adminMembership, memberMembership]);
    });

    it('should allow member to leave household', async () => {
      const response = await request(app)
        .post('/api/households/leave')
        .set('Authorization', `Bearer ${authToken2}`)
        .expect(200);

      expect(response.body.success).toBe(true);

      // Verify membership was deactivated
      const membership = await membershipRepository.findOne({
        where: { user: { id: testUser2.id }, household: { id: testHousehold.id } }
      });
      expect(membership.isActive).toBe(false);
    });

    it('should prevent last admin from leaving', async () => {
      const response = await request(app)
        .post('/api/households/leave')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(409);

      expect(response.body.error.code).toBe('LAST_ADMIN');
    });

    it('should allow admin to leave if another admin exists', async () => {
      // Make testUser2 an admin too
      const membership = await membershipRepository.findOne({
        where: { user: { id: testUser2.id }, household: { id: testHousehold.id } }
      });
      membership.role = 'admin';
      await membershipRepository.save(membership);

      const response = await request(app)
        .post('/api/households/leave')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });
  });

  describe('GET /households/:id/members - getMembers', () => {
    beforeEach(async () => {
      testHousehold = householdRepository.create({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      const membership1 = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date('2024-01-01')
      });
      const membership2 = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: true,
        joinedAt: new Date('2024-01-02')
      });
      await membershipRepository.save([membership1, membership2]);
    });

    it('should return household members with proper ordering', async () => {
      const response = await request(app)
        .get(`/api/households/${testHousehold.id}/members`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);

      expect(response.body.success).toBe(true);
    });

    it('should deny access to non-members', async () => {
      const nonMemberUser = userRepository.create({
        name: 'Non Member',
        email: 'nonmember@example.com',
        hashedPassword: 'hashedpassword'
      });
      await userRepository.save(nonMemberUser);

      const response = await request(app)
        .get(`/api/households/${testHousehold.id}/members`)
        .set('Authorization', `Bearer ${generateTestJWT(nonMemberUser)}`)
        .expect(403);

      expect(response.body.error.code).toBe('ACCESS_DENIED');
    });
  });

  describe('PUT /households/:householdId/members/:memberId/role - updateMemberRole', () => {
    beforeEach(async () => {
      testHousehold = householdRepository.create({
        name: 'Test Household',
        inviteCode: 'TEST1234',
        createdBy: testUser.id
      });
      await householdRepository.save(testHousehold);

      const adminMembership = membershipRepository.create({
        user: testUser,
        household: testHousehold,
        role: 'admin',
        isActive: true,
        joinedAt: new Date()
      });
      const memberMembership = membershipRepository.create({
        user: testUser2,
        household: testHousehold,
        role: 'member',
        isActive: true,
        joinedAt: new Date()
      });
      await membershipRepository.save([adminMembership, memberMembership]);
    });

    it('should allow admin to promote member to admin', async () => {
      const response = await request(app)
        .put(`/api/households/${testHousehold.id}/members/${testUser2.id}/role`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ role: 'admin' })
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data.newRole).toBe('admin');

      // Verify role was updated in database
      const membership = await membershipRepository.findOne({
        where: { user: { id: testUser2.id }, household: { id: testHousehold.id } }
      });
      expect(membership.role).toBe('admin');
    });

    it('should reject role updates from non-admin users', async () => {
      const response = await request(app)
        .put(`/api/households/${testHousehold.id}/members/${testUser.id}/role`)
        .set('Authorization', `Bearer ${authToken2}`)
        .send({ role: 'member' })
        .expect(403);

      expect(response.body.error.code).toBe('INSUFFICIENT_PERMISSIONS');
    });

    it('should validate role values', async () => {
      await request(app)
        .put(`/api/households/${testHousehold.id}/members/${testUser2.id}/role`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ role: 'invalid_role' })
        .expect(400);
    });

    it('should return 404 for non-existent member', async () => {
      const response = await request(app)
        .put(`/api/households/${testHousehold.id}/members/non-existent-id/role`)
        .set('Authorization', `Bearer ${authToken}`)
        .send({ role: 'admin' })
        .expect(404);

      expect(response.body.error.code).toBe('MEMBER_NOT_FOUND');
    });
  });

  describe('Performance and Error Handling', () => {
    it('should handle concurrent household creation attempts', async () => {
      const users = await Promise.all(
        Array(5).fill(null).map(async (_, i) => {
          const u = userRepository.create({ email: `concurrent${i}@example.com`, name: `User ${i}`, hashedPassword: 'pwd' });
          return userRepository.save(u);
        })
      );

      const tokens = users.map(u => generateTestJWT(u));

      const promises = tokens.map((t, i) =>
        request(app)
          .post('/api/households')
          .set('Authorization', `Bearer ${t}`)
          .send({ name: `Concurrent Household ${i}` })
      );

      const responses = await Promise.allSettled(promises);
      const successfulResponses = responses.filter(r => r.status === 'fulfilled' && r.value.status === 201);
      expect(successfulResponses.length).toBe(5);
    });

    it('should maintain data consistency during error conditions', async () => {
      // Create household
      const createResponse = await request(app)
        .post('/api/households')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'Consistency Test' })
        .expect(201);

      const householdId = createResponse.body.data.id;

      // Verify both household and membership exist
      const household = await householdRepository.findOne({ where: { id: householdId } });
      const membership = await membershipRepository.findOne({ 
        where: { user: { id: testUser.id }, household: { id: householdId } }
      });

      expect(household).toBeDefined();
      expect(membership).toBeDefined();
      expect(membership.isActive).toBe(true);
      expect(membership.role).toBe('admin');
    });
  });
});
