import { Request, Response } from 'express';
import { AppDataSource } from '@/config/database';
import { User } from '@/models/User';
import { HouseholdTask } from '@/models/HouseholdTask';
import { UserHouseholdMembership } from '@/models/UserHouseholdMembership';
import { Activity } from '@/models/Activity';
import { TaskComment } from '@/models/TaskComment';
import { logger } from '@/utils/logger';
import { createResponse, createErrorResponse, asyncHandler, ValidationError, UnauthorizedError, NotFoundError } from '@/middleware/errorHandler';
import { validate } from 'class-validator';
import { MoreThan } from 'typeorm';

export class TaskController {
  private taskRepository = AppDataSource.getRepository(HouseholdTask);
  private userRepository = AppDataSource.getRepository(User);
  private membershipRepository = AppDataSource.getRepository(UserHouseholdMembership);
  private activityRepository = AppDataSource.getRepository(Activity);
  private commentRepository = AppDataSource.getRepository(TaskComment);

  /**
   * Create a new task
   */
  async createTask(req: Request, res: Response): Promise<void> {
    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    const {
      title,
      description,
      dueDate,
      priority,
      points,
      isRecurring,
      recurringType,
      recurringInterval,
      assignedUserId,
      householdId
    } = req.body;

    if (!title || title.trim().length < 2) {
      res.status(400).json(createErrorResponse(
        'Task title is required and must be at least 2 characters long',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      // Verify user is a member of the household
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: householdId }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'User is not a member of this household',
          'ACCESS_DENIED'
        ));
        return;
      }

      // Verify assigned user (if specified) is also a member
      if (assignedUserId && assignedUserId !== req.userId) {
        const assignedMembership = await this.membershipRepository.findOne({
          where: { user: { id: assignedUserId }, household: { id: householdId }, isActive: true }
        });

        if (!assignedMembership) {
          res.status(400).json(createErrorResponse(
            'Assigned user is not a member of this household',
            'INVALID_ASSIGNMENT'
          ));
          return;
        }
      }

      // Get household and assigned user entities
      const household = await this.taskRepository.manager.getRepository('Household').findOne({ where: { id: householdId } });
      const assignedUser = assignedUserId ? await this.userRepository.findOne({ where: { id: assignedUserId } }) : undefined;
      
      if (!household) {
        res.status(404).json(createErrorResponse('Household not found', 'HOUSEHOLD_NOT_FOUND'));
        return;
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
        household: household
      });

      const errors = await validate(task);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      const savedTask = await this.taskRepository.save(task);

      // Create activity
      await this.createActivity(
        req.userId,
        householdId,
        'task_created',
        `Created task "${Array.isArray(savedTask) ? savedTask[0]?.title : savedTask.title}"`,
        2, // Small points for creating a task
        Array.isArray(savedTask) ? savedTask[0]?.id : savedTask.id
      );

      // Emit WebSocket event to household members
      const io = req.app.get('io');
      if (io) {
        io.to(`household:${householdId}`).emit('task_created', {
          task: {
            id: Array.isArray(savedTask) ? savedTask[0]?.id : savedTask.id,
            title: Array.isArray(savedTask) ? savedTask[0]?.title : savedTask.title,
            priority: Array.isArray(savedTask) ? savedTask[0]?.priority : savedTask.priority,
            dueDate: Array.isArray(savedTask) ? savedTask[0]?.dueDate : savedTask.dueDate,
            assignedUserId: Array.isArray(savedTask) ? savedTask[0]?.assignedTo?.id : savedTask.assignedTo?.id
          },
          createdBy: {
            id: req.user.id,
            name: req.user.name
          }
        });
      }

      const finalTask = Array.isArray(savedTask) ? savedTask[0] : savedTask;
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

    } catch (error) {
      logger.error('Create task failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to create task',
        'CREATE_TASK_ERROR'
      ));
    }
  }

  /**
   * Get tasks for a household
   */
  async getHouseholdTasks(req: Request, res: Response): Promise<void> {
    const { householdId } = req.params;
    const { completed, assignedToMe, page = 1, limit = 20 } = req.query;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      // Verify user is a member of the household
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: householdId }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'User is not a member of this household',
          'ACCESS_DENIED'
        ));
        return;
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

      const [tasks, total] = await this.taskRepository.findAndCount({
        where,
        relations: ['assignedTo', 'creator', 'comments', 'comments.author'],
        order: { 
          isCompleted: 'ASC', // Incomplete tasks first
          dueDate: 'ASC',
          createdAt: 'DESC'
        },
        take: limitNum,
        skip: offset
      });

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
          commentCount: task.comments?.length || 0,
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

    } catch (error) {
      logger.error('Get household tasks failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get household tasks',
        'GET_TASKS_ERROR'
      ));
    }
  }

  /**
   * Get a specific task with details
   */
  async getTask(req: Request, res: Response): Promise<void> {
    const { taskId } = req.params;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
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
        res.status(404).json(createErrorResponse(
          'Task not found',
          'TASK_NOT_FOUND'
        ));
        return;
      }

      // Verify user is a member of the task's household
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'Access denied',
          'ACCESS_DENIED'
        ));
        return;
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
          avatarColor: task.assignedTo.avatarColor,
          email: task.assignedTo.email
        } : null,
        createdBy: {
          id: task.creator.id,
          name: task.creator.name,
          avatarColor: task.creator.avatarColor
        },
        household: {
          id: task.household.id,
          name: task.household.name
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

    } catch (error) {
      logger.error('Get task failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to get task',
        'GET_TASK_ERROR'
      ));
    }
  }

  /**
   * Complete a task
   */
  async completeTask(req: Request, res: Response): Promise<void> {
    const { taskId } = req.params;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const task = await this.taskRepository.findOne({
        where: { id: taskId },
        relations: ['assignedTo', 'household']
      });

      if (!task) {
        res.status(404).json(createErrorResponse(
          'Task not found',
          'TASK_NOT_FOUND'
        ));
        return;
      }

      if (task.isCompleted) {
        res.status(409).json(createErrorResponse(
          'Task is already completed',
          'TASK_ALREADY_COMPLETED'
        ));
        return;
      }

      // Verify user can complete this task (assigned user or household admin)
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'Access denied',
          'ACCESS_DENIED'
        ));
        return;
      }

      const canComplete = task.assignedTo?.id === req.userId || 
                         !task.assignedTo || 
                         membership.role === 'admin';

      if (!canComplete) {
        res.status(403).json(createErrorResponse(
          'Only the assigned user or household admin can complete this task',
          'INSUFFICIENT_PERMISSIONS'
        ));
        return;
      }

      // Mark task as completed
      task.isCompleted = true;
      task.completedAt = new Date();
      if (!task.assignedTo) {
        const completingUser = await this.userRepository.findOne({ where: { id: req.userId } });
        if (completingUser) {
          task.assignedTo = completingUser; // Assign to the completer if unassigned
        }
      }

      await this.taskRepository.save(task);

      // Award points to the user who completed the task
      const completingUser = await this.userRepository.findOne({
        where: { id: task.assignedTo?.id || req.userId }
      });

      if (completingUser) {
        completingUser.points += task.points;
        
        // Update streak logic (simplified)
        const lastActivity = completingUser.lastActivity;
        const now = new Date();
        const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        if (!lastActivity || lastActivity < yesterday) {
          completingUser.streakDays = 1;
        } else if (lastActivity.toDateString() === yesterday.toDateString()) {
          completingUser.streakDays += 1;
        }
        // If completed today already, don't change streak

        completingUser.lastActivity = now;
        await this.userRepository.save(completingUser);
      }

      // Create activity
      await this.createActivity(
        req.userId,
        task.household.id,
        'task_completed',
        `Completed task "${task.title}"`,
        task.points,
        task.id
      );

      // Handle recurring tasks
      if (task.isRecurring) {
        await this.createNextRecurringTask(task);
      }

      // Emit WebSocket event to household members
      const io = req.app.get('io');
      if (io) {
        io.to(`household:${task.household.id}`).emit('task_completed', {
          task: {
            id: task.id,
            title: task.title,
            points: task.points
          },
          completedBy: {
            id: req.user.id,
            name: req.user.name,
            avatarColor: req.user.avatarColor
          },
          completedAt: task.completedAt
        });
      }

      logger.info('Task completed', { taskId: task.id, userId: req.userId, points: task.points });

      res.json(createResponse({
        id: task.id,
        title: task.title,
        isCompleted: task.isCompleted,
        completedAt: task.completedAt,
        pointsAwarded: task.points,
        newUserPoints: completingUser?.points
      }, 'Task completed successfully'));

    } catch (error) {
      logger.error('Complete task failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to complete task',
        'COMPLETE_TASK_ERROR'
      ));
    }
  }

  /**
   * Update a task
   */
  async updateTask(req: Request, res: Response): Promise<void> {
    const { taskId } = req.params;
    const { title, description, dueDate, priority, points, assignedUserId } = req.body;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    try {
      const task = await this.taskRepository.findOne({
        where: { id: taskId },
        relations: ['household']
      });

      if (!task) {
        res.status(404).json(createErrorResponse(
          'Task not found',
          'TASK_NOT_FOUND'
        ));
        return;
      }

      // Verify user can update this task (creator or household admin)
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'Access denied',
          'ACCESS_DENIED'
        ));
        return;
      }

      const canUpdate = task.createdBy === req.userId || membership.role === 'admin';
      if (!canUpdate) {
        res.status(403).json(createErrorResponse(
          'Only the task creator or household admin can update this task',
          'INSUFFICIENT_PERMISSIONS'
        ));
        return;
      }

      // Update fields if provided
      if (title && title.trim().length >= 2) {
        task.title = title.trim();
      } else if (title) {
        res.status(400).json(createErrorResponse(
          'Task title must be at least 2 characters long',
          'INVALID_TITLE'
        ));
        return;
      }

      if (description !== undefined) {
        task.description = description.trim();
      }

      if (dueDate !== undefined) {
        task.dueDate = dueDate ? new Date(dueDate) : null;
      }

      if (priority && ['low', 'medium', 'high'].includes(priority)) {
        task.priority = priority;
      }

      if (points !== undefined) {
        task.points = Math.max(0, parseInt(points) || 0);
      }

      if (assignedUserId !== undefined) {
        if (assignedUserId) {
          // Verify assigned user is a member of the household
          const assignedMembership = await this.membershipRepository.findOne({
            where: { user: { id: assignedUserId }, household: { id: task.household.id }, isActive: true }
          });

          if (!assignedMembership) {
            res.status(400).json(createErrorResponse(
              'Assigned user is not a member of this household',
              'INVALID_ASSIGNMENT'
            ));
            return;
          }
        }
        if (assignedUserId) {
          const assignedUser = await this.userRepository.findOne({ where: { id: assignedUserId } });
          task.assignedTo = assignedUser || undefined;
        } else {
          task.assignedTo = undefined;
        }
      }

      const errors = await validate(task);
      if (errors.length > 0) {
        res.status(400).json(createErrorResponse(
          'Validation failed',
          'VALIDATION_ERROR',
          errors.map(e => e.constraints)
        ));
        return;
      }

      await this.taskRepository.save(task);

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

    } catch (error) {
      logger.error('Update task failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to update task',
        'UPDATE_TASK_ERROR'
      ));
    }
  }

  /**
   * Add comment to a task
   */
  async addComment(req: Request, res: Response): Promise<void> {
    const { taskId } = req.params;
    const { content } = req.body;

    if (!req.user || !req.userId) {
      res.status(401).json(createErrorResponse(
        'User not authenticated',
        'NOT_AUTHENTICATED'
      ));
      return;
    }

    if (!content || content.trim().length < 1) {
      res.status(400).json(createErrorResponse(
        'Comment content is required',
        'VALIDATION_ERROR'
      ));
      return;
    }

    try {
      const task = await this.taskRepository.findOne({
        where: { id: taskId },
        relations: ['household']
      });

      if (!task) {
        res.status(404).json(createErrorResponse(
          'Task not found',
          'TASK_NOT_FOUND'
        ));
        return;
      }

      // Verify user is a member of the task's household
      const membership = await this.membershipRepository.findOne({
        where: { user: { id: req.userId }, household: { id: task.household.id }, isActive: true }
      });

      if (!membership) {
        res.status(403).json(createErrorResponse(
          'Access denied',
          'ACCESS_DENIED'
        ));
        return;
      }

      const user = await this.userRepository.findOne({ where: { id: req.userId } });
      if (!user) {
        res.status(404).json(createErrorResponse('User not found', 'USER_NOT_FOUND'));
        return;
      }
      
      const comment = this.commentRepository.create({
        content: content.trim(),
        task: task,
        author: user
      });

      const savedComment = await this.commentRepository.save(comment);

      // Load comment with user relation
      const commentWithUser = await this.commentRepository.findOne({
        where: { id: Array.isArray(savedComment) ? savedComment[0].id : savedComment.id },
        relations: ['author']
      });

      logger.info('Comment added to task', { taskId, commentId: Array.isArray(savedComment) ? savedComment[0].id : savedComment.id, userId: req.userId });

      res.status(201).json(createResponse({
        id: commentWithUser!.id,
        content: commentWithUser!.content,
        createdAt: commentWithUser!.createdAt,
        user: {
          id: commentWithUser!.author.id,
          name: commentWithUser!.author.name,
          avatarColor: commentWithUser!.author.avatarColor
        }
      }, 'Comment added successfully'));

    } catch (error) {
      logger.error('Add comment failed:', error);
      res.status(500).json(createErrorResponse(
        'Failed to add comment',
        'ADD_COMMENT_ERROR'
      ));
    }
  }

  /**
   * Helper method to create next recurring task
   */
  private async createNextRecurringTask(originalTask: HouseholdTask): Promise<void> {
    try {
      const now = new Date();
      let nextDueDate: Date | null = null;

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
        dueDate: nextDueDate || undefined,
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

  /**
   * Helper method to create activity records
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
      const user = await this.userRepository.findOne({ where: { id: userId } });
      const household = await this.taskRepository.manager.getRepository('Household').findOne({ where: { id: householdId } });
      
      if (!user || !household) {
        throw new Error('User or household not found for activity');
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

      // Award points to user
      if (points > 0) {
        user.points += points;
        await this.userRepository.save(user);
      }
    } catch (error) {
      logger.error('Failed to create activity:', error);
    }
  }
}
