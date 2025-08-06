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
import { IsEmail, IsNotEmpty, MinLength } from 'class-validator';
import { UserHouseholdMembership } from './UserHouseholdMembership';
import { HouseholdTask } from './HouseholdTask';
import { Activity } from './Activity';
import { RewardRedemption } from './RewardRedemption';
import { TaskComment } from './TaskComment';
import { Challenge } from './Challenge';
import { Badge } from './Badge';
import bcrypt from 'bcrypt';

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

  @Column({ default: 0 })
  points!: number;

  @Column({ name: 'streak_days', default: 0 })
  streakDays!: number;

  @Column({ name: 'last_activity', nullable: true })
  lastActivity?: Date;

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
