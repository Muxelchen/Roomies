import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
  ManyToOne,
  BeforeInsert
} from 'typeorm';
import { IsNotEmpty } from 'class-validator';
import { UserHouseholdMembership } from './UserHouseholdMembership';
import { HouseholdTask } from './HouseholdTask';
import { Reward } from './Reward';
import { Challenge } from './Challenge';
import { Activity } from './Activity';
import { User } from './User';

@Entity('households')
export class Household {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  name!: string;

  @Column({ name: 'invite_code', unique: true })
  inviteCode!: string;

  @Column({ name: 'created_by' })
  createdBy!: string;

  @Column({ default: '{}' })
  settings!: string; // JSON string for household settings

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => User)
  creator!: User;

  @OneToMany(() => UserHouseholdMembership, membership => membership.household)
  memberships!: UserHouseholdMembership[];

  @OneToMany(() => HouseholdTask, task => task.household)
  tasks!: HouseholdTask[];

  @OneToMany(() => Reward, reward => reward.household)
  rewards!: Reward[];

  @OneToMany(() => Challenge, challenge => challenge.household)
  challenges!: Challenge[];

  @OneToMany(() => Activity, activity => activity.household)
  activities!: Activity[];

  // Auto-generate invite code before insert
  @BeforeInsert()
  generateInviteCode() {
    if (!this.inviteCode) {
      this.inviteCode = this.generateRandomCode(6);
    }
  }

  private generateRandomCode(length: number): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  // Helper methods
  get activeMembers(): UserHouseholdMembership[] {
    return this.memberships?.filter(m => m.isActive) || [];
  }

  get memberCount(): number {
    return this.activeMembers.length;
  }

  get activeTasks(): HouseholdTask[] {
    return this.tasks?.filter(t => !t.isCompleted) || [];
  }

  get completedTasks(): HouseholdTask[] {
    return this.tasks?.filter(t => t.isCompleted) || [];
  }

  get availableRewards(): Reward[] {
    return this.rewards?.filter(r => r.isAvailable) || [];
  }

  get activeChallenges(): Challenge[] {
    return this.challenges?.filter(c => c.isActive && c.dueDate && c.dueDate > new Date()) || [];
  }

  // Get household statistics
  getTotalPointsEarned(): number {
    return this.activeMembers.reduce((total, member) => {
      return total + (member.user?.points || 0);
    }, 0);
  }

  getTotalTasksCompleted(): number {
    return this.completedTasks.length;
  }

  getLeaderboard(): Array<{ user: User; points: number; tasksCompleted: number; streakDays: number }> {
    return this.activeMembers
      .map(member => ({
        user: member.user,
        points: member.user?.points || 0,
        tasksCompleted: member.user?.getTotalTasksCompleted() || 0,
        streakDays: member.user?.streakDays || 0
      }))
      .sort((a, b) => b.points - a.points);
  }

  getRecentActivity(limit: number = 10): Activity[] {
    return this.activities
      ?.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .slice(0, limit) || [];
  }

  // Check if user is member
  isMember(userId: string): boolean {
    return this.activeMembers.some(member => member.user?.id === userId);
  }

  // Check if user is admin
  isAdmin(userId: string): boolean {
    const membership = this.activeMembers.find(member => member.user?.id === userId);
    return membership?.role === 'admin';
  }

  // Get member role
  getMemberRole(userId: string): string | null {
    const membership = this.activeMembers.find(member => member.user?.id === userId);
    return membership?.role || null;
  }

  // Household settings management
  getSettings(): any {
    try {
      return JSON.parse(this.settings);
    } catch {
      return {};
    }
  }

  updateSettings(newSettings: any): void {
    const currentSettings = this.getSettings();
    this.settings = JSON.stringify({ ...currentSettings, ...newSettings });
  }

  // Task management helpers
  getTasksForUser(userId: string): HouseholdTask[] {
    return this.tasks?.filter(task => task.assignedTo?.id === userId) || [];
  }

  getOverdueTasks(): HouseholdTask[] {
    const now = new Date();
    return this.tasks?.filter(task => 
      !task.isCompleted && 
      task.dueDate && 
      task.dueDate < now
    ) || [];
  }

  getTasksCompletedToday(): HouseholdTask[] {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    return this.tasks?.filter(task => 
      task.isCompleted && 
      task.completedAt && 
      task.completedAt >= today && 
      task.completedAt < tomorrow
    ) || [];
  }
}
