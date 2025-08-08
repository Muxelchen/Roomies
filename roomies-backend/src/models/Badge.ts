import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToMany
} from 'typeorm';
import { IsNotEmpty } from 'class-validator';
import { User } from './User';

export type BadgeType = 
  | 'task_completion'
  | 'points_earned'
  | 'household_join'
  | 'streak'
  | 'challenge_completion'
  | 'reward_redemption'
  | 'social'
  | 'special';

@Entity('badges')
export class Badge {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  name!: string;

  @Column({ name: 'badge_description', nullable: true })
  description?: string;

  @Column({ name: 'icon_name', default: 'star.fill' })
  iconName!: string;

  @Column({ default: 'blue' })
  color!: string;

  @Column()
  requirement!: number; // The threshold to earn this badge

  @Column({ 
    type: 'simple-enum', 
    enum: ['task_completion', 'points_earned', 'household_join', 'streak', 'challenge_completion', 'reward_redemption', 'social', 'special'],
    default: 'task_completion' 
  })
  type!: BadgeType;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ name: 'rarity', default: 'common' })
  rarity!: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary';

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToMany(() => User, user => user.badges)
  earnedBy!: User[];

  // Helper methods
  get earnedCount(): number {
    return this.earnedBy?.length || 0;
  }

  get rarityWeight(): number {
    switch (this.rarity) {
      case 'common': return 1;
      case 'uncommon': return 2;
      case 'rare': return 3;
      case 'epic': return 4;
      case 'legendary': return 5;
      default: return 1;
    }
  }

  get rarityColor(): string {
    switch (this.rarity) {
      case 'common': return 'gray';
      case 'uncommon': return 'green';
      case 'rare': return 'blue';
      case 'epic': return 'purple';
      case 'legendary': return 'orange';
      default: return 'gray';
    }
  }

  // Check if user meets requirements for this badge
  checkRequirements(user: User): boolean {
    if (!this.isActive) return false;

    switch (this.type) {
      case 'task_completion':
        return user.getTotalTasksCompleted() >= this.requirement;
      
      case 'points_earned':
        return user.points >= this.requirement;
      
      case 'household_join':
        return (user.householdMemberships?.length || 0) >= this.requirement;
      
      case 'streak':
        return user.streakDays >= this.requirement;
      
      case 'challenge_completion':
        // This would need to be implemented based on how challenges are tracked
        return false; // Placeholder
      
      case 'reward_redemption':
        return (user.rewardRedemptions?.length || 0) >= this.requirement;
      
      case 'social':
        // This could be based on household member count, activities, etc.
        return false; // Placeholder
      
      case 'special':
        // Special badges might have custom logic
        return false; // Placeholder
      
      default:
        return false;
    }
  }

  // Check if user has already earned this badge
  hasBeenEarnedBy(userId: string): boolean {
    return this.earnedBy?.some(user => user.id === userId) || false;
  }

  // Award this badge to a user
  awardTo(user: User): boolean {
    if (this.hasBeenEarnedBy(user.id) || !this.checkRequirements(user)) {
      return false;
    }

    if (!this.earnedBy) {
      this.earnedBy = [];
    }
    this.earnedBy.push(user);
    return true;
  }

  // Management methods
  activate(): void {
    this.isActive = true;
  }

  deactivate(): void {
    this.isActive = false;
  }

  updateRequirement(newRequirement: number): void {
    if (newRequirement < 1) throw new Error('Requirement must be at least 1');
    this.requirement = newRequirement;
  }

  updateRarity(newRarity: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary'): void {
    this.rarity = newRarity;
  }

  // Analytics helpers
  getEarnRate(): number {
    // This would need total user count to be meaningful
    return this.earnedCount; // Simplified for now
  }

  getAgeInDays(): number {
    return Math.floor((Date.now() - this.createdAt.getTime()) / (1000 * 60 * 60 * 24));
  }

  // Badge creation helpers
  static createTaskCompletionBadge(name: string, description: string, requirement: number, rarity: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' = 'common'): Partial<Badge> {
    return {
      name,
      description,
      requirement,
      type: 'task_completion',
      iconName: 'checkmark.circle.fill',
      color: 'green',
      rarity,
      isActive: true
    };
  }

  static createPointsBadge(name: string, description: string, requirement: number, rarity: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' = 'common'): Partial<Badge> {
    return {
      name,
      description,
      requirement,
      type: 'points_earned',
      iconName: 'star.fill',
      color: 'yellow',
      rarity,
      isActive: true
    };
  }

  static createStreakBadge(name: string, description: string, requirement: number, rarity: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' = 'common'): Partial<Badge> {
    return {
      name,
      description,
      requirement,
      type: 'streak',
      iconName: 'flame.fill',
      color: 'orange',
      rarity,
      isActive: true
    };
  }

  static createSocialBadge(name: string, description: string, requirement: number, rarity: 'common' | 'uncommon' | 'rare' | 'epic' | 'legendary' = 'common'): Partial<Badge> {
    return {
      name,
      description,
      requirement,
      type: 'household_join',
      iconName: 'person.3.fill',
      color: 'blue',
      rarity,
      isActive: true
    };
  }

  // Progress tracking for users
  getProgressForUser(user: User): { current: number; target: number; percentage: number } {
    let current = 0;

    switch (this.type) {
      case 'task_completion':
        current = user.getTotalTasksCompleted();
        break;
      case 'points_earned':
        current = user.points;
        break;
      case 'household_join':
        current = user.householdMemberships?.length || 0;
        break;
      case 'streak':
        current = user.streakDays;
        break;
      case 'reward_redemption':
        current = user.rewardRedemptions?.length || 0;
        break;
      default:
        current = 0;
    }

    return {
      current,
      target: this.requirement,
      percentage: Math.min(100, Math.floor((current / this.requirement) * 100))
    };
  }
}
