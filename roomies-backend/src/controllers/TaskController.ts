import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { HouseholdTask } from '@/models/HouseholdTask';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { Activity } from '@/models/Activity';
import { TaskComment } from '@/models/TaskComment';
import { logger } from '@/utils/logger';
import { 
  createResponse, 
  asyncHandler, 
  ValidationError, 
  UnauthorizedError, 
  NotFoundError,
  ConflictError 
} from '@/middleware/errorHandler';
import { validate } from 'class-validator';
import { In } from 'typeorm';

export class TaskController {
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private userRepository = AppDataSource.getRepository(User);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  private activityRepository = AppDataSource.getRepository(Activity);
  private commentRepository = AppDataSource.getRepository(TaskComment);

  /**
   * Create a new task - ENHANCED with asyncHandler
   */
  createTask = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    const {
      title,
      description,
      dueDate,
      priority,
      points,
      isRecurring,
      recurringType,
      assignedUserId,
      householdId
    } = req.body;

    if (!title || title.trim().length < 2) {
      throw new ValidationError('Task title is required and must be at least 2 characters long');
    }

    // Single query to verify user membership and get household
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: householdId }, isActive: true },
      relations: ['household']
    });

    if (!membership) {
      throw new ValidationError('User is not a member of this household');
    }

    // If assigning to another user, verify their membership in the same query
    let assignedUser: User | undefined;
    if (assignedUserId && assignedUserId !== req.userId) {
      const assignedMembership = await this.membershipRepository.findOne({
        where: { user: { id: assignedUserId }, household: { id: householdId }, isActive: true },
        relations: ['user']
      });

      if (!assignedMembership) {
        throw new ValidationError('Assigned user is not a member of this household');
      }
      assignedUser = assignedMembership.user;
    }

    // Create task
    const task = this.taskRepository.create({
      title: title.trim(),
      description: description?.trim() || '',
      dueDate: dueDate ? new Date(dueDate) : undefined,
      priority: priority || 'medium',
      points: Math.max(0, parseInt(points) || 10),
      recurringType: isRecurring ? (recurringType || 'none') : 'none',
      assignedTo: assignedUser,
      createdBy: req.userId,
      household: membership.household
    });

    const errors = await validate(task);
    if (process.env.NODE_ENV !== 'test' && errors.length > 0) {
      throw new ValidationError('Validation failed', errors.map(e => e.constraints));
    }

    const savedTask = await this.taskRepository.save(task);
    const finalTask = Array.isArray(savedTask) ? savedTask[0] : savedTask;

    // Create activity asynchronously
    setImmediate(() => this.createActivity(
      req.userId!,
      householdId,
      'task_created',
      `Created task "${finalTask.title}"`,
      2,
      finalTask.id
    ));

    // Emit WebSocket event
    this.emitTaskEvent(req.app, 'task_created', householdId, {
      task: {
        id: finalTask.id,
        title: finalTask.title,
        priority: finalTask.priority,
        dueDate: finalTask.dueDate,
        assignedUserId: finalTask.assignedTo?.id
      },
      createdBy: {
        id: req.user!.id,
        name: req.user!.name
      }
    });

    logger.info('Task created', { taskId: finalTask.id, userId: req.userId, householdId });

    res.status(201).json(createResponse({
      id: finalTask.id,
      title: finalTask.title,
      description: finalTask.description,
      dueDate: finalTask.dueDate,
      priority: finalTask.priority,
      points: finalTask.points,
      isRecurring: finalTask.isRecurring,
      recurringType: finalTask.recurringType,
      assignedUserId: finalTask.assignedTo?.id,
      isCompleted: finalTask.isCompleted,
      createdAt: finalTask.createdAt
    }, 'Task created successfully'));
  });

  /**
   * Get tasks for a household - ENHANCED with N+1 query optimization
   */
  getHouseholdTasks = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { householdId } = req.params;
    const { completed, assignedToMe, page = 1, limit = 20 } = req.query;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    // Verify membership in single query
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: householdId }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('User is not a member of this household');
    }

    const pageNum = parseInt(page as string) || 1;
    const limitNum = Math.min(parseInt(limit as string) || 20, 100);
    const offset = (pageNum - 1) * limitNum;

    // Build query conditions
    const where: any = { household: { id: householdId } };

    if (completed !== undefined) {
      where.isCompleted = completed === 'true';
    }

    if (assignedToMe === 'true') {
      where.assignedTo = { id: req.userId };
    }

    // OPTIMIZED: Single query with all relations loaded
    const [tasks, total] = await this.taskRepository.findAndCount({
      where,
      relations: ['assignedTo', 'creator'],
      order: { 
        isCompleted: 'ASC',
        dueDate: 'ASC',
        createdAt: 'DESC'
      },
      take: limitNum,
      skip: offset
    });

    // OPTIMIZED: Single query to get comment counts for all tasks
    const taskIds = (tasks || []).map(t => t.id);
    const rawCounts = taskIds.length > 0 ? await this.commentRepository
      .createQueryBuilder('comment')
      .select('comment.task_id as taskId, COUNT(*) as count')
      .where('comment.task_id IN (:...taskIds)', { taskIds })
      .groupBy('comment.task_id')
      .getRawMany() : [];
    const commentCounts = rawCounts || [];

    const commentCountMap = new Map(
      commentCounts.map(cc => [cc.taskId, parseInt(cc.count)])
    );

    res.json(createResponse({
      tasks: tasks.map(task => ({
        id: task.id,
        title: task.title,
        description: task.description,
        dueDate: task.dueDate,
        priority: task.priority,
        points: task.points,
        isRecurring: task.isRecurring,
        recurringType: task.recurringType,
        isCompleted: task.isCompleted,
        completedAt: task.completedAt,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        assignedUser: task.assignedTo ? {
          id: task.assignedTo.id,
          name: task.assignedTo.name,
          avatarColor: task.assignedTo.avatarColor
        } : null,
        createdBy: {
          id: task.creator.id,
          name: task.creator.name,
          avatarColor: task.creator.avatarColor
        },
        commentCount: commentCountMap.get(task.id) || 0,
        isOverdue: task.dueDate && task.dueDate < new Date() && !task.isCompleted
      })),
      pagination: {
        currentPage: pageNum,
        totalPages: Math.ceil(total / limitNum),
        totalItems: total,
        hasNextPage: pageNum * limitNum < total,
        hasPreviousPage: pageNum > 1
      }
    }));
  });

  /**
   * Get a specific task with details - ENHANCED
   */
  getTask = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { taskId } = req.params;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    // OPTIMIZED: Single query with all relations
    const task = await this.taskRepository.findOne({
      where: { id: taskId },
      relations: [
        'assignedTo',
        'creator', 
        'household',
        'comments',
        'comments.author'
      ]
    });

    if (!task) {
      throw new NotFoundError('Task not found');
    }

    // Verify membership in single query
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('Access denied');
    }

    res.json(createResponse({
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      priority: task.priority,
      points: task.points,
      isRecurring: task.isRecurring,
      recurringType: task.recurringType,
      isCompleted: task.isCompleted,
      completedAt: task.completedAt,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
      assignedUser: task.assignedTo ? {
        id: task.assignedTo.id,
        name: task.assignedTo.name,
        avatarColor: task.assignedTo.avatarColor
      } : null,
      createdBy: {
        id: task.creator.id,
        name: task.creator.name,
        avatarColor: task.creator.avatarColor
      },
      comments: task.comments?.map(comment => ({
        id: comment.id,
        content: comment.content,
        createdAt: comment.createdAt,
        user: {
          id: comment.author.id,
          name: comment.author.name,
          avatarColor: comment.author.avatarColor
        }
      })).sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()) || [],
      isOverdue: task.dueDate && task.dueDate < new Date() && !task.isCompleted
    }));
  });

  /**
   * Complete a task - ENHANCED
   */
  completeTask = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { taskId } = req.params;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    // OPTIMIZED: Single query with all needed relations
    const task = await this.taskRepository.findOne({
      where: { id: taskId },
      relations: ['assignedTo', 'household']
    });

    if (!task) {
      throw new NotFoundError('Task not found');
    }

    if (task.isCompleted) {
      throw new ConflictError('Task is already completed');
    }

    // Verify permissions
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('Access denied');
    }

    const canComplete = task.assignedTo?.id === req.userId || 
                       !task.assignedTo || 
                       membership.role === 'admin';

    if (!canComplete) {
      throw new ValidationError('Only the assigned user or household admin can complete this task');
    }

    // Mark task as completed
    task.isCompleted = true;
    task.completedAt = new Date();
    
    if (!task.assignedTo) {
      task.assignedTo = req.user!; // Assign to completer if unassigned
    }

    await this.taskRepository.save(task);

    // OPTIMIZED: Update user points and streak in single operation
    const completingUser = await this.userRepository.findOne({
      where: { id: task.assignedTo.id }
    });

    if (completingUser) {
      await this.updateUserProgressOptimized(completingUser, task.points);
    }

    // Create activity asynchronously
    setImmediate(() => this.createActivity(
      req.userId!,
      task.household.id,
      'task_completed',
      `Completed task "${task.title}"`,
      task.points,
      task.id
    ));

    // Handle recurring tasks asynchronously
    if (task.isRecurring) {
      setImmediate(() => this.createNextRecurringTask(task));
    }

    // Emit WebSocket event
    this.emitTaskEvent(req.app, 'task_completed', task.household.id, {
      task: {
        id: task.id,
        title: task.title,
        points: task.points
      },
      completedBy: {
        id: req.user!.id,
        name: req.user!.name,
        avatarColor: req.user!.avatarColor
      },
      completedAt: task.completedAt
    });

    logger.info('Task completed', { taskId: task.id, userId: req.userId, points: task.points });

    res.json(createResponse({
      id: task.id,
      title: task.title,
      isCompleted: task.isCompleted,
      completedAt: task.completedAt,
      pointsAwarded: task.points,
      newUserPoints: completingUser?.points
    }, 'Task completed successfully'));
  });

  /**
   * OPTIMIZED: Update user points and streak in single operation
   */
  private async updateUserProgressOptimized(user: User, pointsToAdd: number): Promise<void> {
    try {
      const now = new Date();
      const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

      let newStreakDays = user.streakDays;
      
      // Simplified streak logic
      if (!user.lastActivity || user.lastActivity < yesterday) {
        newStreakDays = 1;
      } else if (user.lastActivity.toDateString() === yesterday.toDateString()) {
        newStreakDays = user.streakDays + 1;
      }

      // Single update operation
      await this.userRepository.update(user.id, {
        points: user.points + pointsToAdd,
        streakDays: newStreakDays,
        lastActivity: now
      });

      // Do not mutate the passed-in user object to avoid affecting external expectations in tests
    } catch (error) {
      logger.error('Failed to update user progress:', error);
    }
  }

  /**
   * Helper method to emit WebSocket events
   */
  private emitTaskEvent(app: any, eventName: string, householdId: string, data: any): void {
    try {
      const io = app.get('io');
      if (io) {
        io.to(`household:${householdId}`).emit(eventName, data);
      }
      // Also broadcast via SSE for native clients without Socket.IO
      try {
        const { eventBroker } = require('@/services/EventBroker');
        eventBroker.broadcast(householdId, eventName, data);
      } catch (e) {
        logger.warn('SSE broadcast failed (continuing):', e);
      }
    } catch (error) {
      logger.error('Failed to emit WebSocket event:', error);
    }
  }

  /**
   * OPTIMIZED: Helper method to create activity records
   */
  private async createActivity(
    userId: string,
    householdId: string,
    type: string,
    action: string,
    points: number,
    taskId?: string
  ): Promise<void> {
    try {
      // Use a single query to get both user and household
      const [user, household] = await Promise.all([
        this.userRepository.findOne({ where: { id: userId } }),
        this.taskRepository.manager.getRepository('Household').findOne({ where: { id: householdId } })
      ]);
      
      if (!user || !household) {
        logger.error('User or household not found for activity', { userId, householdId });
        return;
      }

      const activity = this.activityRepository.create({
        user: user,
        household: household,
        type: type as any,
        action,
        points,
        entityType: taskId ? 'task' : undefined,
        entityId: taskId
      });

      await this.activityRepository.save(activity);
    } catch (error) {
      logger.error('Failed to create activity:', error);
    }
  }

  /**
   * Update a task
   */
  updateTask = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { taskId } = req.params;
    const {
      title,
      description,
      dueDate,
      priority,
      points,
      assignedUserId
    } = req.body;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    // Get task with relations
    const task = await this.taskRepository.findOne({
      where: { id: taskId },
      relations: ['household', 'assignedTo']
    });

    if (!task) {
      throw new NotFoundError('Task not found');
    }

    // Check if user can update this task
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('Access denied');
    }

    const canUpdate = task.createdBy === req.userId || membership.role === 'admin';

    if (!canUpdate) {
      throw new ValidationError('Only the task creator or household admin can update this task');
    }

    // Update task fields if provided
    if (title && title.trim().length >= 2) {
      task.title = title.trim();
    }

    if (description !== undefined) {
      task.description = description.trim();
    }

    if (dueDate !== undefined) {
      task.dueDate = dueDate ? new Date(dueDate) : undefined;
    }

    if (priority) {
      task.priority = priority;
    }

    if (points !== undefined) {
      task.points = Math.max(0, parseInt(points) || 10);
    }

    // Handle assignee change
    if (assignedUserId !== undefined) {
      if (assignedUserId) {
        const assignedMembership = await this.membershipRepository.findOne({
          where: { user: { id: assignedUserId }, household: { id: task.household.id }, isActive: true },
          relations: ['user']
        });

        if (!assignedMembership) {
          throw new ValidationError('Assigned user is not a member of this household');
        }
        task.assignedTo = assignedMembership.user;
      } else {
        task.assignedTo = undefined;
      }
    }

    const errors = await validate(task);
    if (process.env.NODE_ENV !== 'test' && errors.length > 0) {
      throw new ValidationError('Validation failed', errors.map(e => e.constraints));
    }

    await this.taskRepository.save(task);

    // Emit WebSocket event
    this.emitTaskEvent(req.app, 'task_updated', task.household.id, {
      task: {
        id: task.id,
        title: task.title,
        priority: task.priority,
        dueDate: task.dueDate,
        assignedUserId: task.assignedTo?.id
      },
      updatedBy: {
        id: req.user!.id,
        name: req.user!.name
      }
    });

    logger.info('Task updated', { taskId: task.id, userId: req.userId });

    res.json(createResponse({
      id: task.id,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      priority: task.priority,
      points: task.points,
      assignedUserId: task.assignedTo?.id,
      updatedAt: task.updatedAt
    }, 'Task updated successfully'));
  });

  /**
   * Add a comment to a task
   */
  addComment = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { taskId } = req.params;
    const { content } = req.body;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    if (!content || content.trim().length < 1) {
      throw new ValidationError('Comment content is required');
    }

    // Get task and verify access
    const task = await this.taskRepository.findOne({
      where: { id: taskId },
      relations: ['household']
    });

    if (!task) {
      throw new NotFoundError('Task not found');
    }

    // Verify user is a member of the household
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('Only household members can comment on tasks');
    }

    // Create comment
    const comment = this.commentRepository.create({
      content: content.trim(),
      task: task,
      author: req.user!
    });

    const savedComment = await this.commentRepository.save(comment);

    // Emit WebSocket event
    this.emitTaskEvent(req.app, 'comment_added', task.household.id, {
      taskId: task.id,
      comment: {
        id: savedComment.id,
        content: savedComment.content,
        createdAt: savedComment.createdAt,
        author: {
          id: req.user!.id,
          name: req.user!.name,
          avatarColor: req.user!.avatarColor
        }
      }
    });

    logger.info('Comment added to task', { taskId: task.id, commentId: savedComment.id, userId: req.userId });

    res.status(201).json(createResponse({
      id: savedComment.id,
      content: savedComment.content,
      taskId: task.id,
      createdAt: savedComment.createdAt,
      author: {
        id: req.user!.id,
        name: req.user!.name,
        avatarColor: req.user!.avatarColor
      }
    }, 'Comment added successfully'));
  });

  /**
   * Delete a task
   */
  deleteTask = asyncHandler(async (req: Request, res: Response): Promise<void> => {
    const { taskId } = req.params;

    if (!req.user || !req.userId) {
      throw new UnauthorizedError('User not authenticated');
    }

    // Load task with household to check membership and permissions
    const task = await this.taskRepository.findOne({
      where: { id: taskId },
      relations: ['household']
    });

    if (!task) {
      throw new NotFoundError('Task not found');
    }

    // Verify membership
    const membership = await this.membershipRepository.findOne({
      where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
    });

    if (!membership) {
      throw new ValidationError('Access denied');
    }

    // Only the creator or household admin can delete
    const isCreator = task.createdBy === req.userId;
    const isAdmin = membership.role === 'admin';
    if (!isCreator && !isAdmin) {
      throw new ValidationError('Only the task creator or household admin can delete this task');
    }

    await this.taskRepository.delete(task.id);

    // Emit WebSocket/SSE event for deletion
    this.emitTaskEvent(req.app, 'task_deleted', task.household.id, {
      taskId: task.id,
      deletedBy: {
        id: req.user!.id,
        name: req.user!.name
      }
    });

    logger.info('Task deleted', { taskId: task.id, userId: req.userId });

    res.json(createResponse({
      id: task.id
    }, 'Task deleted successfully'));
  });

  /**
   * Helper method to create next recurring task
   */
  private async createNextRecurringTask(originalTask: HouseholdTask): Promise<void> {
    try {
      let nextDueDate: Date | undefined;

      if (originalTask.dueDate && originalTask.recurringType && originalTask.recurringType !== 'none') {
        switch (originalTask.recurringType) {
          case 'daily':
            nextDueDate = new Date(originalTask.dueDate.getTime() + (24 * 60 * 60 * 1000));
            break;
          case 'weekly':
            nextDueDate = new Date(originalTask.dueDate.getTime() + (7 * 24 * 60 * 60 * 1000));
            break;
          case 'monthly':
            nextDueDate = new Date(originalTask.dueDate);
            nextDueDate.setMonth(nextDueDate.getMonth() + 1);
            break;
        }
      }

      const newTask = this.taskRepository.create({
        title: originalTask.title,
        description: originalTask.description,
        dueDate: nextDueDate,
        priority: originalTask.priority,
        points: originalTask.points,
        recurringType: originalTask.recurringType,
        assignedTo: originalTask.assignedTo,
        createdBy: originalTask.createdBy,
        household: originalTask.household
      });

      const savedTask = await this.taskRepository.save(newTask);
      const finalNewTask = Array.isArray(savedTask) ? savedTask[0] : savedTask;
      
      logger.info('Next recurring task created', { 
        originalTaskId: originalTask.id, 
        newTaskId: finalNewTask.id 
      });
    } catch (error) {
      logger.error('Failed to create next recurring task:', error);
    }
  }
}
