import bcrypt from 'bcrypt';
import { IsEmail, IsNotEmpty, MinLength } from 'class-validator';
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToMany,
  JoinTable,
  BeforeInsert,
  BeforeUpdate
} from 'typeorm';

import { Activity } from './Activity';
import { Badge } from './Badge';
import { Challenge } from './Challenge';
import { HouseholdTask } from './HouseholdTask';
import { RewardRedemption } from './RewardRedemption';
import { TaskComment } from './TaskComment';
import { UserHouseholdMembership } from './UserHouseholdMembership';


@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ unique: true })
  @IsEmail()
  email!: string;

  @Column()
  @IsNotEmpty()
  name!: string;

  @Column({ name: 'hashed_password' })
  @MinLength(8)
  hashedPassword!: string;

  @Column({ name: 'avatar_color', default: 'blue' })
  avatarColor!: string;

  @Column({ name: 'avatar_url', nullable: true })
  avatarUrl?: string | null;

  // Sign in with Apple linkage (nullable for non-Apple accounts)
  @Column({ name: 'apple_user_id', type: 'varchar', unique: true, nullable: true })
  appleUserId?: string | null;

  @Column({ default: 0 })
  points!: number;

  @Column({ name: 'streak_days', default: 0 })
  streakDays!: number;

  @Column({ name: 'last_activity', nullable: true })
  lastActivity?: Date;

  // Email verification
  @Column({ name: 'email_verified', type: 'boolean', default: false })
  emailVerified!: boolean;

  @Column({ name: 'email_verification_token_hash', type: 'varchar', nullable: true })
  emailVerificationTokenHash?: string | null;

  @Column({ name: 'email_verification_expires', nullable: true })
  emailVerificationExpires?: Date | null;

  // Password reset
  @Column({ name: 'password_reset_token_hash', type: 'varchar', nullable: true })
  passwordResetTokenHash?: string | null;

  @Column({ name: 'password_reset_expires', nullable: true })
  passwordResetExpires?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @OneToMany(() => UserHouseholdMembership, membership => membership.user)
  householdMemberships!: UserHouseholdMembership[];

  @OneToMany(() => HouseholdTask, task => task.assignedTo)
  assignedTasks!: HouseholdTask[];

  @OneToMany(() => HouseholdTask, task => task.completedBy)
  completedTasks!: HouseholdTask[];

  @OneToMany(() => Activity, activity => activity.user)
  activities!: Activity[];

  @OneToMany(() => RewardRedemption, redemption => redemption.redeemedBy)
  rewardRedemptions!: RewardRedemption[];

  @OneToMany(() => TaskComment, comment => comment.author)
  comments!: TaskComment[];

  @ManyToMany(() => Challenge, challenge => challenge.participants)
  challenges!: Challenge[];

  @ManyToMany(() => Badge)
  @JoinTable({
    name: 'user_badges',
    joinColumn: { name: 'user_id' },
    inverseJoinColumn: { name: 'badge_id' }
  })
  badges!: Badge[];

  // Virtual fields (not stored in database)
  get level(): number {
    return Math.floor(this.points / 100) + 1;
  }

  get currentHousehold(): string | null {
    const membership = this.householdMemberships?.find(m => m.isActive);
    return membership?.household?.id || null;
  }

  // Password handling
  @BeforeInsert()
  @BeforeUpdate()
  async hashPassword() {
    if (this.hashedPassword && !this.hashedPassword.startsWith('$2b$')) {
      this.hashedPassword = await bcrypt.hash(this.hashedPassword, 12);
    }
  }

  async validatePassword(password: string): Promise<boolean> {
    return bcrypt.compare(password, this.hashedPassword);
  }

  // Helper methods
  isHouseholdAdmin(householdId: string): boolean {
    const membership = this.householdMemberships?.find(
      m => m.household.id === householdId && m.isActive
    );
    return membership?.role === 'admin';
  }

  getTasksCompletedThisWeek(): number {
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);
    
    return this.completedTasks?.filter(
      task => task.completedAt && task.completedAt >= oneWeekAgo
    ).length || 0;
  }

  getTotalTasksCompleted(): number {
    return this.completedTasks?.length || 0;
  }

  updateStreak(): void {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const todayTasks = this.completedTasks?.filter(task => {
      if (!task.completedAt) return false;
      const completedDate = new Date(task.completedAt);
      return completedDate.toDateString() === today.toDateString();
    });

    const yesterdayTasks = this.completedTasks?.filter(task => {
      if (!task.completedAt) return false;
      const completedDate = new Date(task.completedAt);
      return completedDate.toDateString() === yesterday.toDateString();
    });

    if (todayTasks && todayTasks.length > 0) {
      if (yesterdayTasks && yesterdayTasks.length > 0) {
        this.streakDays += 1;
      } else if (this.streakDays === 0) {
        this.streakDays = 1;
      }
    } else if (!yesterdayTasks || yesterdayTasks.length === 0) {
      this.streakDays = 0;
    }
  }
}
