import express, { Request, Response } from 'express';
import { TaskController } from '@/controllers/TaskController';
import { authenticateToken } from '@/middleware/auth';
import { asyncHandler } from '@/middleware/errorHandler';

const router = express.Router();
const taskController = new TaskController();

// All task routes require authentication
router.use(authenticateToken);

/**
 * @route   POST /api/tasks
 * @desc    Create a new task
 * @access  Private (Household members)
 * @body    { title: string, description?: string, dueDate?: string, priority?: string, points?: number, isRecurring?: boolean, recurringType?: string, recurringInterval?: number, assignedUserId?: string, householdId: string }
 */
router.post('/', asyncHandler(async (req: Request, res: Response) => {
  await taskController.createTask(req, res);
}));

/**
 * @route   GET /api/tasks/household/:householdId
 * @desc    Get tasks for a household
 * @access  Private (Household members)
 * @query   { completed?: boolean, assignedToMe?: boolean, page?: number, limit?: number }
 */
router.get('/household/:householdId', asyncHandler(async (req: Request, res: Response) => {
  await taskController.getHouseholdTasks(req, res);
}));

/**
 * @route   GET /api/tasks/:taskId
 * @desc    Get a specific task with details
 * @access  Private (Household members)
 */
router.get('/:taskId', asyncHandler(async (req: Request, res: Response) => {
  await taskController.getTask(req, res);
}));

/**
 * @route   PUT /api/tasks/:taskId
 * @desc    Update a task
 * @access  Private (Task creator or household admin)
 * @body    { title?: string, description?: string, dueDate?: string, priority?: string, points?: number, assignedUserId?: string }
 */
router.put('/:taskId', asyncHandler(async (req: Request, res: Response) => {
  await taskController.updateTask(req, res);
}));

/**
 * @route   POST /api/tasks/:taskId/complete
 * @desc    Mark a task as completed
 * @access  Private (Assigned user or household admin)
 */
router.post('/:taskId/complete', asyncHandler(async (req: Request, res: Response) => {
  await taskController.completeTask(req, res);
}));

/**
 * @route   POST /api/tasks/:taskId/comments
 * @desc    Add a comment to a task
 * @access  Private (Household members)
 * @body    { content: string }
 */
router.post('/:taskId/comments', asyncHandler(async (req: Request, res: Response) => {
  await taskController.addComment(req, res);
}));

export default router;
