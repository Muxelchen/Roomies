import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  OneToMany,
  JoinColumn
} from 'typeorm';
import { IsNotEmpty, Min, Max } from 'class-validator';
import { User } from './User';
import { Household } from './Household';
import { TaskComment } from './TaskComment';

export type TaskPriority = 'low' | 'medium' | 'high';
export type RecurringType = 'none' | 'daily' | 'weekly' | 'monthly';

@Entity('household_tasks')
export class HouseholdTask {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  title!: string;

  @Column({ name: 'task_description', nullable: true })
  description?: string;

  @Column()
  @Min(1)
  @Max(100)
  points!: number;

  @Column({ name: 'is_completed', default: false })
  isCompleted!: boolean;

  @Column({ type: 'enum', enum: ['low', 'medium', 'high'], default: 'medium' })
  priority!: TaskPriority;

  @Column({ name: 'recurring_type', type: 'enum', enum: ['none', 'daily', 'weekly', 'monthly'], default: 'none' })
  recurringType!: RecurringType;

  @Column({ name: 'due_date', nullable: true })
  dueDate?: Date;

  @Column({ name: 'completed_at', nullable: true })
  completedAt?: Date;

  @Column({ name: 'created_by' })
  createdBy!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => Household, household => household.tasks)
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  @ManyToOne(() => User, user => user.assignedTasks, { nullable: true })
  @JoinColumn({ name: 'assigned_to' })
  assignedTo?: User;

  @ManyToOne(() => User, user => user.completedTasks, { nullable: true })
  @JoinColumn({ name: 'completed_by' })
  completedBy?: User;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'created_by', referencedColumnName: 'id' })
  creator!: User;

  @OneToMany(() => TaskComment, comment => comment.task)
  comments!: TaskComment[];

  // Helper methods
  get isOverdue(): boolean {
    if (!this.dueDate || this.isCompleted) return false;
    return new Date() > this.dueDate;
  }

  get timeRemaining(): string | null {
    if (!this.dueDate || this.isCompleted) return null;
    
    const now = new Date();
    const due = new Date(this.dueDate);
    const diffMs = due.getTime() - now.getTime();
    
    if (diffMs < 0) return 'Overdue';
    
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (diffDays > 0) {
      return `${diffDays} day${diffDays > 1 ? 's' : ''}`;
    } else if (diffHours > 0) {
      return `${diffHours} hour${diffHours > 1 ? 's' : ''}`;
    } else {
      const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      return `${diffMinutes} minute${diffMinutes > 1 ? 's' : ''}`;
    }
  }

  complete(completedBy: User): void {
    this.isCompleted = true;
    this.completedAt = new Date();
    this.completedBy = completedBy;
  }

  assign(user: User): void {
    this.assignedTo = user;
  }

  unassign(): void {
    this.assignedTo = undefined;
  }

  updatePriority(priority: TaskPriority): void {
    this.priority = priority;
  }

  updateDueDate(dueDate: Date | null): void {
    this.dueDate = dueDate || undefined;
  }

  // Recurring task helpers
  get isRecurring(): boolean {
    return this.recurringType !== 'none';
  }

  getNextDueDate(): Date | null {
    if (!this.isRecurring || !this.dueDate) return null;

    const nextDate = new Date(this.dueDate);
    
    switch (this.recurringType) {
      case 'daily':
        nextDate.setDate(nextDate.getDate() + 1);
        break;
      case 'weekly':
        nextDate.setDate(nextDate.getDate() + 7);
        break;
      case 'monthly':
        nextDate.setMonth(nextDate.getMonth() + 1);
        break;
      default:
        return null;
    }
    
    return nextDate;
  }

  createRecurringInstance(): Partial<HouseholdTask> {
    if (!this.isRecurring) return {};

    const nextDueDate = this.getNextDueDate();
    if (!nextDueDate) return {};

    return {
      title: this.title,
      description: this.description,
      points: this.points,
      priority: this.priority,
      recurringType: this.recurringType,
      dueDate: nextDueDate,
      household: this.household,
      assignedTo: this.assignedTo,
      createdBy: this.createdBy
    };
  }

  // Priority helpers
  get priorityWeight(): number {
    switch (this.priority) {
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 1;
    }
  }

  get priorityColor(): string {
    switch (this.priority) {
      case 'high': return 'red';
      case 'medium': return 'orange';
      case 'low': return 'green';
      default: return 'gray';
    }
  }

  // Status helpers
  get status(): 'completed' | 'overdue' | 'pending' {
    if (this.isCompleted) return 'completed';
    if (this.isOverdue) return 'overdue';
    return 'pending';
  }

  get canBeCompleted(): boolean {
    return !this.isCompleted;
  }

  // Comment helpers
  get commentCount(): number {
    return this.comments?.length || 0;
  }

  addComment(content: string, author: User): TaskComment {
    const comment = new TaskComment();
    comment.content = content;
    comment.author = author;
    comment.task = this;
    comment.createdAt = new Date();
    return comment;
  }
}
