import { IsNotEmpty } from 'class-validator';
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';

import { HouseholdTask } from './HouseholdTask';
import { User } from './User';

@Entity('task_comments')
export class TaskComment {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  content!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => User, user => user.comments)
  @JoinColumn({ name: 'author_id' })
  author!: User;

  @ManyToOne(() => HouseholdTask, task => task.comments, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'task_id' })
  task!: HouseholdTask;

  // Helper methods
  get commentAge(): string {
    const now = new Date();
    const diffMs = now.getTime() - this.createdAt.getTime();
    const diffMinutes = Math.floor(diffMs / (1000 * 60));
    const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffMinutes < 1) return 'Just now';
    if (diffMinutes < 60) return `${diffMinutes}m ago`;
    if (diffHours < 24) return `${diffHours}h ago`;
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays}d ago`;
    return this.createdAt.toLocaleDateString();
  }

  get isRecent(): boolean {
    const oneHourAgo = new Date();
    oneHourAgo.setHours(oneHourAgo.getHours() - 1);
    return this.createdAt >= oneHourAgo;
  }

  get wasEdited(): boolean {
    return this.updatedAt.getTime() !== this.createdAt.getTime();
  }

  // Content management
  updateContent(newContent: string): void {
    if (!newContent.trim()) {
      throw new Error('Comment content cannot be empty');
    }
    this.content = newContent.trim();
    this.updatedAt = new Date();
  }

  // Permission helpers
  canBeEditedBy(userId: string): boolean {
    return this.author.id === userId;
  }

  canBeDeletedBy(userId: string): boolean {
    // Author can delete, or household admin can delete
    if (this.author.id === userId) return true;
    
    // Check if user is admin of the task's household
    const household = this.task.household;
    return household.isAdmin(userId);
  }
}
