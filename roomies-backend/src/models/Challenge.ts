import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  ManyToMany,
  JoinTable,
  JoinColumn
} from 'typeorm';
import { IsNotEmpty, Min } from 'class-validator';
import { User } from './User';
import { Household } from './Household';

@Entity('challenges')
export class Challenge {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  title!: string;

  @Column({ name: 'challenge_description', nullable: true })
  description?: string;

  @Column({ name: 'point_reward' })
  @Min(1)
  pointReward!: number;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ name: 'due_date', nullable: true })
  dueDate?: Date;

  @Column({ name: 'max_participants', nullable: true })
  maxParticipants?: number;

  @Column({ name: 'completion_criteria', default: '{}' })
  completionCriteria!: string; // JSON string for criteria

  @Column({ name: 'icon_name', default: 'trophy' })
  iconName!: string;

  @Column({ default: 'orange' })
  color!: string;

  @Column({ name: 'created_by' })
  createdBy!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => Household, household => household.challenges)
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'created_by', referencedColumnName: 'id' })
  creator!: User;

  @ManyToMany(() => User, user => user.challenges)
  @JoinTable({
    name: 'challenge_participants',
    joinColumn: { name: 'challenge_id' },
    inverseJoinColumn: { name: 'user_id' }
  })
  participants!: User[];

  // Helper methods
  get isExpired(): boolean {
    if (!this.dueDate) return false;
    return new Date() > this.dueDate;
  }

  get canJoin(): boolean {
    if (!this.isActive || this.isExpired) return false;
    if (!this.maxParticipants) return true;
    return this.participants.length < this.maxParticipants;
  }

  get participantCount(): number {
    return this.participants?.length || 0;
  }

  get remainingSlots(): number | null {
    if (!this.maxParticipants) return null;
    return Math.max(0, this.maxParticipants - this.participantCount);
  }

  get timeRemaining(): string | null {
    if (!this.dueDate) return null;
    
    const now = new Date();
    const due = new Date(this.dueDate);
    const diffMs = due.getTime() - now.getTime();
    
    if (diffMs < 0) return 'Expired';
    
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    const diffHours = Math.floor((diffMs % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    if (diffDays > 0) {
      return `${diffDays} day${diffDays > 1 ? 's' : ''} left`;
    } else if (diffHours > 0) {
      return `${diffHours} hour${diffHours > 1 ? 's' : ''} left`;
    } else {
      const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));
      return `${diffMinutes} minute${diffMinutes > 1 ? 's' : ''} left`;
    }
  }

  // Participant management
  canUserJoin(user: User): boolean {
    if (!this.canJoin) return false;
    return !this.isUserParticipant(user.id);
  }

  isUserParticipant(userId: string): boolean {
    return this.participants?.some(p => p.id === userId) || false;
  }

  addParticipant(user: User): void {
    if (!this.canUserJoin(user)) {
      throw new Error('User cannot join this challenge');
    }
    
    if (!this.participants) {
      this.participants = [];
    }
    this.participants.push(user);
  }

  removeParticipant(user: User): void {
    if (!this.participants) return;
    
    const index = this.participants.findIndex(p => p.id === user.id);
    if (index > -1) {
      this.participants.splice(index, 1);
    }
  }

  // Status helpers
  get status(): 'active' | 'expired' | 'full' | 'inactive' {
    if (!this.isActive) return 'inactive';
    if (this.isExpired) return 'expired';
    if (!this.canJoin && this.maxParticipants) return 'full';
    return 'active';
  }

  get statusColor(): string {
    switch (this.status) {
      case 'active': return 'green';
      case 'expired': return 'red';
      case 'full': return 'orange';
      case 'inactive': return 'gray';
      default: return 'gray';
    }
  }

  // Completion criteria helpers
  getCriteria(): any {
    try {
      return JSON.parse(this.completionCriteria);
    } catch {
      return {};
    }
  }

  updateCriteria(newCriteria: any): void {
    this.completionCriteria = JSON.stringify(newCriteria);
  }

  checkCompletion(user: User): boolean {
    const criteria = this.getCriteria();
    
    // Default completion check - this can be extended based on criteria type
    if (criteria.type === 'tasks') {
      const requiredTasks = criteria.count || 1;
      const userTasksCompleted = user.getTasksCompletedThisWeek();
      return userTasksCompleted >= requiredTasks;
    }
    
    if (criteria.type === 'points') {
      const requiredPoints = criteria.amount || 100;
      return user.points >= requiredPoints;
    }
    
    if (criteria.type === 'streak') {
      const requiredDays = criteria.days || 7;
      return user.streakDays >= requiredDays;
    }
    
    return false;
  }

  getCompletionProgress(user: User): { current: number; target: number; percentage: number } {
    const criteria = this.getCriteria();
    
    if (criteria.type === 'tasks') {
      const current = user.getTasksCompletedThisWeek();
      const target = criteria.count || 1;
      return {
        current,
        target,
        percentage: Math.min(100, Math.floor((current / target) * 100))
      };
    }
    
    if (criteria.type === 'points') {
      const current = user.points;
      const target = criteria.amount || 100;
      return {
        current,
        target,
        percentage: Math.min(100, Math.floor((current / target) * 100))
      };
    }
    
    if (criteria.type === 'streak') {
      const current = user.streakDays;
      const target = criteria.days || 7;
      return {
        current,
        target,
        percentage: Math.min(100, Math.floor((current / target) * 100))
      };
    }
    
    return { current: 0, target: 1, percentage: 0 };
  }

  // Management methods
  activate(): void {
    this.isActive = true;
  }

  deactivate(): void {
    this.isActive = false;
  }

  extend(newDueDate: Date): void {
    this.dueDate = newDueDate;
    if (!this.isActive && !this.isExpired) {
      this.isActive = true;
    }
  }

  updateReward(newReward: number): void {
    if (newReward < 1) throw new Error('Reward must be at least 1 point');
    this.pointReward = newReward;
  }

  // Analytics helpers
  getEngagementRate(): number {
    if (!this.maxParticipants) return 0;
    return (this.participantCount / this.maxParticipants) * 100;
  }

  getAgeInDays(): number {
    return Math.floor((Date.now() - this.createdAt.getTime()) / (1000 * 60 * 60 * 24));
  }

  // Difficulty helpers (based on criteria and reward)
  get difficulty(): 'easy' | 'medium' | 'hard' | 'extreme' {
    const criteria = this.getCriteria();
    const rewardPerPoint = this.pointReward;
    
    // Simple heuristic based on reward amount
    if (rewardPerPoint <= 10) return 'easy';
    if (rewardPerPoint <= 25) return 'medium';
    if (rewardPerPoint <= 50) return 'hard';
    return 'extreme';
  }

  get difficultyColor(): string {
    switch (this.difficulty) {
      case 'easy': return 'green';
      case 'medium': return 'blue';
      case 'hard': return 'orange';
      case 'extreme': return 'red';
      default: return 'gray';
    }
  }
}
