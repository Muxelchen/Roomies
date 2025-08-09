import { TaskController } from '@/controllers/TaskController';
import { authenticateToken } from '@/middleware/auth';
import { taskPaginationMiddleware, paginationMonitoringMiddleware } from '@/middleware/pagination';
import { expensiveOperationLimiter } from '@/middleware/rateLimiter';
import { validateRequest, schemas, validateUUID } from '@/middleware/validation';
import express from 'express';

const router = express.Router();
const taskController = new TaskController();

// All task routes require authentication
router.use(authenticateToken);

/**
 * @route   POST /api/tasks
 * @desc    Create a new task - ENHANCED with validation and rate limiting
 * @access  Private (Household members)
 * @body    { title: string, description?: string, dueDate?: string, priority?: string, points?: number, isRecurring?: boolean, recurringType?: string, assignedUserId?: string, householdId: string }
 */
router.post('/', 
  validateRequest(schemas.createTask),
  expensiveOperationLimiter(20), // Limit task creation
  taskController.createTask
);

/**
 * @route   GET /api/tasks/household/:householdId
 * @desc    Get tasks for a household - ENHANCED with pagination and monitoring
 * @access  Private (Household members)
 * @query   { completed?: boolean, assignedToMe?: boolean, page?: number, limit?: number, sortBy?: string, sortOrder?: string }
 */
router.get('/household/:householdId', 
  validateUUID('householdId'),
  taskPaginationMiddleware(),
  paginationMonitoringMiddleware(),
  taskController.getHouseholdTasks
);

/**
 * @route   GET /api/tasks/my-tasks
 * @desc    Get tasks assigned to current user across their active household
 */
router.get('/my-tasks', taskController.getMyTasks);

/**
 * @route   GET /api/tasks/:taskId
 * @desc    Get a specific task with details - ENHANCED with validation
 * @access  Private (Household members)
 */
router.get('/:taskId', 
  validateUUID('taskId'),
  taskController.getTask
);

/**
 * @route   PUT /api/tasks/:taskId
 * @desc    Update a task - ENHANCED with validation
 * @access  Private (Task creator or household admin)
 * @body    { title?: string, description?: string, dueDate?: string, priority?: string, points?: number, assignedUserId?: string }
 */
router.put('/:taskId', 
  validateUUID('taskId'),
  validateRequest(schemas.updateTask),
  taskController.updateTask
);

/**
 * @route   DELETE /api/tasks/:taskId
 * @desc    Delete a task - ENHANCED with validation
 * @access  Private (Task creator or household admin)
 */
router.delete('/:taskId', 
  validateUUID('taskId'),
  taskController.deleteTask
);

/**
 * @route   POST /api/tasks/:taskId/complete
 * @desc    Mark a task as completed - ENHANCED with rate limiting for points
 * @access  Private (Assigned user or household admin)
 */
router.post('/:taskId/complete', 
  validateUUID('taskId'),
  expensiveOperationLimiter(50), // Prevent task completion spam
  taskController.completeTask
);

/**
 * @route   POST /api/tasks/:taskId/assign
 * @desc    Assign task to a user (creator or admin)
 */
router.post('/:taskId/assign', 
  validateUUID('taskId'),
  taskController.assignTask
);

/**
 * @route   POST /api/tasks/:taskId/comments
 * @desc    Add a comment to a task - ENHANCED with validation and rate limiting
 * @access  Private (Household members)
 * @body    { content: string }
 */
router.post('/:taskId/comments', 
  validateUUID('taskId'),
  validateRequest(schemas.taskComment),
  expensiveOperationLimiter(100), // Limit comment spam
  taskController.addComment
);

export default router;
