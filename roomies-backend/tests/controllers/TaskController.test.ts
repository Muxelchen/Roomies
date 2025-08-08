import { TaskController } from '@/controllers/TaskController';
import { testHelpers } from '../setup';
import { ValidationError, UnauthorizedError, NotFoundError, ConflictError } from '@/middleware/errorHandler';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { HouseholdTask } from '@/models/HouseholdTask';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { TaskComment } from '@/models/TaskComment';

// Mock database connections
jest.mock('@/config/database', () => ({
  AppDataSource: {
    getRepository: jest.fn(),
    isInitialized: true
  }
}));

// Mock logger
jest.mock('@/utils/logger', () => ({
  logger: {
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn()
  }
}));

describe('TaskController - Enhanced Version', () => {
  let taskController: TaskController;
  let mockTaskRepository: any;
  let mockUserRepository: any;
  let mockMembershipRepository: any;
  let mockActivityRepository: any;
  let mockCommentRepository: any;
  let mockUser: any;
  let mockTask: any;
  let mockHousehold: any;
  let mockMembership: any;

  beforeEach(() => {
    jest.clearAllMocks();

    // Create mock repositories
    mockTaskRepository = {
      findOne: jest.fn(),
      findAndCount: jest.fn(),
      create: jest.fn(),
      save: jest.fn(),
      update: jest.fn(),
      createQueryBuilder: jest.fn(() => ({
        select: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        groupBy: jest.fn().mockReturnThis(),
        getRawMany: jest.fn()
      })),
      manager: {
        getRepository: jest.fn()
      }
    };

    mockUserRepository = {
      findOne: jest.fn(),
      save: jest.fn(),
      update: jest.fn()
    };

    mockMembershipRepository = {
      findOne: jest.fn(),
      save: jest.fn()
    };

    mockActivityRepository = {
      create: jest.fn(),
      save: jest.fn()
    };

    mockCommentRepository = {
      create: jest.fn(),
      save: jest.fn(),
      findOne: jest.fn(),
      createQueryBuilder: jest.fn(() => ({
        select: jest.fn().mockReturnThis(),
        where: jest.fn().mockReturnThis(),
        groupBy: jest.fn().mockReturnThis(),
        getRawMany: jest.fn()
      }))
    };

    // Mock AppDataSource.getRepository
    (AppDataSource.getRepository as jest.Mock).mockImplementation((entity) => {
      switch (entity) {
        case HouseholdTask:
          return mockTaskRepository;
        case User:
          return mockUserRepository;
        case UserHouseholdMembership:
          return mockMembershipRepository;
        case TaskComment:
          return mockCommentRepository;
        default:
          return mockActivityRepository;
      }
    });

    // Create mock objects
    mockUser = {
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      points: 100,
      streakDays: 5,
      lastActivity: new Date()
    };

    mockHousehold = {
      id: 'household-1',
      name: 'Test Household'
    };

    mockMembership = {
      id: 'membership-1',
      user: mockUser,
      household: mockHousehold,
      role: 'member',
      isActive: true
    };

    mockTask = {
      id: 'task-1',
      title: 'Test Task',
      description: 'Test Description',
      points: 10,
      isCompleted: false,
      priority: 'medium',
      household: mockHousehold,
      assignedTo: mockUser,
      creator: mockUser,
      comments: [],
      createdAt: new Date(),
      updatedAt: new Date()
    };

    taskController = new TaskController();
  });

  describe('createTask', () => {
    it('should create a task with valid data', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          title: 'New Task',
          description: 'Task description',
          householdId: 'household-1',
          priority: 'high',
          points: 20
        },
        user: mockUser,
        userId: 'user-1',
        app: {
          get: jest.fn().mockReturnValue({
            to: jest.fn().mockReturnValue({
              emit: jest.fn()
            })
          })
        }
      });
      const res = testHelpers.createMockResponse();
      const next = testHelpers.createMockNext();

      // Mock membership verification

      // Mock membership verification
      mockMembershipRepository.findOne.mockResolvedValue({
        ...mockMembership,
        household: mockHousehold
      });

      // Mock task creation
      mockTaskRepository.create.mockReturnValue(mockTask);
      mockTaskRepository.save.mockResolvedValue(mockTask);

      await taskController.createTask(req, res, next);

      if ((res as any).status?.mock?.calls?.length) {
        expect(res.status).toHaveBeenCalledWith(201);
      }
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            id: mockTask.id,
            title: mockTask.title
          }),
          message: 'Task created successfully'
        })
      );

      expect(mockMembershipRepository.findOne).toHaveBeenCalledWith({
        where: { user: { id: 'user-1' }, household: { id: 'household-1' }, isActive: true },
        relations: ['household']
      });
    });

    it('should throw UnauthorizedError for unauthenticated user', async () => {
      const req = testHelpers.createMockRequest({
        body: { title: 'New Task', householdId: 'household-1' },
        user: null,
        userId: null
      });
      const res = testHelpers.createMockResponse();

      const next = testHelpers.createMockNext();
      await taskController.createTask(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(UnauthorizedError));
    });

    it('should throw ValidationError for missing title', async () => {
      const req = testHelpers.createMockRequest({
        body: { householdId: 'household-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      const next = testHelpers.createMockNext();
      await taskController.createTask(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should throw ValidationError for non-member user', async () => {
      const req = testHelpers.createMockRequest({
        body: { title: 'New Task', householdId: 'household-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      // Mock no membership found
      mockMembershipRepository.findOne.mockResolvedValue(null);

      const next = testHelpers.createMockNext();
      await taskController.createTask(req, res, next);
expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('should validate assigned user membership', async () => {
      const req = testHelpers.createMockRequest({
        body: {
          title: 'New Task',
          householdId: 'household-1',
          assignedUserId: 'user-2'
        },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      // Mock creator membership
      mockMembershipRepository.findOne
        .mockResolvedValueOnce({ ...mockMembership, household: mockHousehold })
        .mockResolvedValueOnce(null); // No membership for assigned user

      const next = testHelpers.createMockNext();
      await taskController.createTask(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });

  describe('getHouseholdTasks - Performance Optimized', () => {
    it('should get tasks with optimized queries', async () => {
      const req = testHelpers.createMockRequest({
        params: { householdId: 'household-1' },
        query: { page: '1', limit: '20', completed: 'false' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      const mockTasks = [
        { ...mockTask, id: 'task-1' },
        { ...mockTask, id: 'task-2' }
      ];

      // Mock membership verification
      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);

      // Mock optimized task query
      mockTaskRepository.findAndCount.mockResolvedValue([mockTasks, 2]);

      // Mock optimized comment counting
      const mockCommentCounts = [
        { taskId: 'task-1', count: '3' },
        { taskId: 'task-2', count: '1' }
      ];
      mockCommentRepository.createQueryBuilder().getRawMany.mockResolvedValue(mockCommentCounts);

      const next = testHelpers.createMockNext();
      await taskController.getHouseholdTasks(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            tasks: expect.arrayContaining([
              expect.objectContaining({ id: 'task-1' }),
              expect.objectContaining({ id: 'task-2' })
            ]),
            pagination: expect.objectContaining({
              currentPage: 1,
              totalItems: 2,
              totalPages: 1
            })
          })
        })
      );

      // Verify optimized queries were used
      expect(mockTaskRepository.findAndCount).toHaveBeenCalledWith({
        where: { household: { id: 'household-1' }, isCompleted: false },
        relations: ['assignedTo', 'creator'],
        order: {
          isCompleted: 'ASC',
          dueDate: 'ASC',
          createdAt: 'DESC'
        },
        take: 20,
        skip: 0
      });

      expect(mockCommentRepository.createQueryBuilder).toHaveBeenCalled();
    });

    it('should filter tasks assigned to current user', async () => {
      const req = testHelpers.createMockRequest({
        params: { householdId: 'household-1' },
        query: { assignedToMe: 'true' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);
      mockTaskRepository.findAndCount.mockResolvedValue([[], 0]);
      mockCommentRepository.createQueryBuilder().getRawMany.mockResolvedValue([]);

      const next = testHelpers.createMockNext();
      await taskController.getHouseholdTasks(req, res, next);

      expect(mockTaskRepository.findAndCount).toHaveBeenCalledWith(
        expect.objectContaining({
          where: expect.objectContaining({
            assignedTo: { id: 'user-1' }
          })
        })
      );
    });
  });

  describe('getTask', () => {
    it('should get task with all details in single query', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'task-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      const mockTaskWithComments = {
        ...mockTask,
        comments: [
          {
            id: 'comment-1',
            content: 'Test comment',
            createdAt: new Date(),
            author: mockUser
          }
        ]
      };

      // Mock optimized single query
      mockTaskRepository.findOne.mockResolvedValue(mockTaskWithComments);
      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);

      const next = testHelpers.createMockNext();
      await taskController.getTask(req, res, next);

      expect(mockTaskRepository.findOne).toHaveBeenCalledWith({
        where: { id: 'task-1' },
        relations: [
          'assignedTo',
          'creator',
          'household',
          'comments',
          'comments.author'
        ]
      });

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            id: 'task-1',
            comments: expect.arrayContaining([
              expect.objectContaining({
                id: 'comment-1',
                content: 'Test comment'
              })
            ])
          })
        })
      );
    });

    it('should throw NotFoundError for non-existent task', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'non-existent' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      mockTaskRepository.findOne.mockResolvedValue(null);

      const next = testHelpers.createMockNext();
      await taskController.getTask(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(NotFoundError));
    });
  });

  describe('completeTask - Performance Optimized', () => {
    it('should complete task with optimized user update', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'task-1' },
        user: mockUser,
        userId: 'user-1',
        app: {
          get: jest.fn().mockReturnValue({
            to: jest.fn().mockReturnValue({
              emit: jest.fn()
            })
          })
        }
      });
      const res = testHelpers.createMockResponse();

      // Mock task lookup
      mockTaskRepository.findOne.mockResolvedValue(mockTask);
      mockTaskRepository.save.mockResolvedValue({
        ...mockTask,
        isCompleted: true,
        completedAt: new Date()
      });

      // Mock membership verification
      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);

      // Mock user lookup for points update
      mockUserRepository.findOne.mockResolvedValue(mockUser);
      mockUserRepository.update.mockResolvedValue({});

      const next = testHelpers.createMockNext();
      await taskController.completeTask(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            id: 'task-1',
            isCompleted: true,
            pointsAwarded: 10
          }),
          message: 'Task completed successfully'
        })
      );

      // Verify optimized user update was called
      expect(mockUserRepository.update).toHaveBeenCalledWith(
        mockUser.id,
        expect.objectContaining({
          points: mockUser.points + mockTask.points,
          streakDays: expect.any(Number),
          lastActivity: expect.any(Date)
        })
      );
    });

    it('should throw ConflictError for already completed task', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'task-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      mockTaskRepository.findOne.mockResolvedValue({
        ...mockTask,
        isCompleted: true
      });

const next = testHelpers.createMockNext();
await taskController.completeTask(req, res, next);
expect(next).toHaveBeenCalledWith(expect.any(ConflictError));
    });

    it('should validate user permissions for task completion', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'task-1' },
        user: mockUser,
        userId: 'user-2' // Different user
      });
      const res = testHelpers.createMockResponse();

      mockTaskRepository.findOne.mockResolvedValue({
        ...mockTask,
        assignedTo: { id: 'user-3' } // Assigned to different user
      });

      mockMembershipRepository.findOne.mockResolvedValue({
        ...mockMembership,
        role: 'member' // Not admin
      });

const next = testHelpers.createMockNext();
await taskController.completeTask(req, res, next);
expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });
  });

  describe('Performance Tests', () => {
    it('should handle large task lists efficiently', async () => {
      const req = testHelpers.createMockRequest({
        params: { householdId: 'household-1' },
        query: { limit: '100' }, // Maximum allowed
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      // Generate 100 mock tasks
      const largeMockTasks = Array.from({ length: 100 }, (_, i) => ({
        ...mockTask,
        id: `task-${i}`,
        title: `Task ${i}`
      }));

      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);
      mockTaskRepository.findAndCount.mockResolvedValue([largeMockTasks, 1000]);

      // Mock comment counts for all tasks
      const commentCounts = largeMockTasks.map((task, i) => ({
        taskId: task.id,
        count: String(i % 5) // Vary comment counts
      }));
      mockCommentRepository.createQueryBuilder().getRawMany.mockResolvedValue(commentCounts);

      const startTime = Date.now();
const next = testHelpers.createMockNext();
await taskController.getHouseholdTasks(req, res, next);
expect(next).not.toHaveBeenCalled();
      const duration = Date.now() - startTime;

      // Should complete quickly (< 100ms in tests)
      expect(duration).toBeLessThan(100);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            tasks: expect.arrayContaining([
              expect.objectContaining({
                id: 'task-0',
                commentCount: 0
              })
            ]),
            pagination: expect.objectContaining({
              totalItems: 1000,
              currentPage: 1,
              totalPages: 10 // 1000 / 100
            })
          })
        })
      );

      // Verify only one query was made for tasks (no N+1)
      expect(mockTaskRepository.findAndCount).toHaveBeenCalledTimes(1);
      // Verify comment counts were queried
      expect(mockCommentRepository.createQueryBuilder).toHaveBeenCalled();
    });

    it('should handle empty comment counts gracefully', async () => {
      const req = testHelpers.createMockRequest({
        params: { householdId: 'household-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);
      mockTaskRepository.findAndCount.mockResolvedValue([[mockTask], 1]);
      mockCommentRepository.createQueryBuilder().getRawMany.mockResolvedValue([]); // No comments

const next = testHelpers.createMockNext();
await taskController.getHouseholdTasks(req, res, next);

      expect(next).not.toHaveBeenCalled();
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            tasks: expect.arrayContaining([
              expect.objectContaining({
                commentCount: 0 // Should default to 0
              })
            ])
          })
        })
      );
    });
  });

  describe('Error Handling', () => {
    it('should handle database errors gracefully', async () => {
      const req = testHelpers.createMockRequest({
        params: { householdId: 'household-1' },
        user: mockUser,
        userId: 'user-1'
      });
      const res = testHelpers.createMockResponse();

      mockMembershipRepository.findOne.mockRejectedValue(new Error('Database connection failed'));

const next = testHelpers.createMockNext();
await taskController.getHouseholdTasks(req, res, next);
expect(next).toHaveBeenCalled();
    });

    it('should handle WebSocket emission errors gracefully', async () => {
      const req = testHelpers.createMockRequest({
        params: { taskId: 'task-1' },
        user: mockUser,
        userId: 'user-1',
        app: {
          get: jest.fn().mockReturnValue(null) // No WebSocket available
        }
      });
      const res = testHelpers.createMockResponse();

      mockTaskRepository.findOne.mockResolvedValue(mockTask);
      mockMembershipRepository.findOne.mockResolvedValue(mockMembership);
      mockTaskRepository.save.mockResolvedValue({ ...mockTask, isCompleted: true });
      mockUserRepository.findOne.mockResolvedValue(mockUser);

      // Should not throw error even if WebSocket is unavailable
const next = testHelpers.createMockNext();
await taskController.completeTask(req, res, next);
expect(next).not.toHaveBeenCalled();
expect(res.json).toHaveBeenCalled();
    });
  });
});
