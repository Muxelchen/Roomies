import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';
import { User } from './User';
import { Household } from './Household';

export type ActivityType = 
  | 'task_completed' 
  | 'task_created' 
  | 'task_assigned'
  | 'reward_redeemed' 
  | 'challenge_joined' 
  | 'challenge_completed'
  | 'member_joined'
  | 'member_left'
  | 'household_created'
  | 'points_earned'
  | 'badge_earned'
  | 'level_up';

@Entity('activities')
export class Activity {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'simple-enum', enum: [
    'task_completed', 'task_created', 'task_assigned',
    'reward_redeemed', 'challenge_joined', 'challenge_completed',
    'member_joined', 'member_left', 'household_created',
    'points_earned', 'badge_earned', 'level_up'
  ]})
  type!: ActivityType;

  @Column()
  action!: string; // Human-readable action description

  @Column({ default: 0 })
  points!: number; // Points involved in this activity

  @Column({ name: 'entity_type', nullable: true })
  entityType?: string; // Type of entity involved (task, reward, challenge, etc.)

  @Column({ name: 'entity_id', nullable: true })
  entityId?: string; // ID of the entity involved

  @Column({ default: '{}' })
  metadata!: string; // JSON string for additional data

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  // Relationships
  @ManyToOne(() => User, user => user.activities)
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => Household, household => household.activities)
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  // Helper methods
  get activityAge(): string {
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

  get icon(): string {
    switch (this.type) {
      case 'task_completed': return 'checkmark.circle.fill';
      case 'task_created': return 'plus.circle.fill';
      case 'task_assigned': return 'person.fill';
      case 'reward_redeemed': return 'gift.fill';
      case 'challenge_joined': return 'flag.fill';
      case 'challenge_completed': return 'trophy.fill';
      case 'member_joined': return 'person.badge.plus.fill';
      case 'member_left': return 'person.badge.minus.fill';
      case 'household_created': return 'house.fill';
      case 'points_earned': return 'star.fill';
      case 'badge_earned': return 'crown.fill';
      case 'level_up': return 'arrow.up.circle.fill';
      default: return 'circle.fill';
    }
  }

  get color(): string {
    switch (this.type) {
      case 'task_completed': return 'green';
      case 'task_created': return 'blue';
      case 'task_assigned': return 'orange';
      case 'reward_redeemed': return 'purple';
      case 'challenge_joined': return 'orange';
      case 'challenge_completed': return 'gold';
      case 'member_joined': return 'green';
      case 'member_left': return 'red';
      case 'household_created': return 'blue';
      case 'points_earned': return 'yellow';
      case 'badge_earned': return 'purple';
      case 'level_up': return 'rainbow';
      default: return 'gray';
    }
  }

  // Metadata helpers
  getMetadata(): any {
    try {
      return JSON.parse(this.metadata);
    } catch {
      return {};
    }
  }

  updateMetadata(newMetadata: any): void {
    const currentMetadata = this.getMetadata();
    this.metadata = JSON.stringify({ ...currentMetadata, ...newMetadata });
  }

  // Activity creation helpers
  static createTaskCompleted(user: User, household: Household, taskTitle: string, points: number): Activity {
    const activity = new Activity();
    activity.type = 'task_completed';
    activity.action = `completed "${taskTitle}"`;
    activity.points = points;
    activity.entityType = 'task';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ taskTitle });
    activity.createdAt = new Date();
    return activity;
  }

  static createTaskCreated(user: User, household: Household, taskTitle: string): Activity {
    const activity = new Activity();
    activity.type = 'task_created';
    activity.action = `created task "${taskTitle}"`;
    activity.points = 0;
    activity.entityType = 'task';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ taskTitle });
    activity.createdAt = new Date();
    return activity;
  }

  static createRewardRedeemed(user: User, household: Household, rewardName: string, pointsSpent: number): Activity {
    const activity = new Activity();
    activity.type = 'reward_redeemed';
    activity.action = `redeemed "${rewardName}"`;
    activity.points = -pointsSpent;
    activity.entityType = 'reward';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ rewardName, pointsSpent });
    activity.createdAt = new Date();
    return activity;
  }

  static createChallengeJoined(user: User, household: Household, challengeTitle: string): Activity {
    const activity = new Activity();
    activity.type = 'challenge_joined';
    activity.action = `joined challenge "${challengeTitle}"`;
    activity.points = 0;
    activity.entityType = 'challenge';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ challengeTitle });
    activity.createdAt = new Date();
    return activity;
  }

  static createChallengeCompleted(user: User, household: Household, challengeTitle: string, points: number): Activity {
    const activity = new Activity();
    activity.type = 'challenge_completed';
    activity.action = `completed challenge "${challengeTitle}"`;
    activity.points = points;
    activity.entityType = 'challenge';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ challengeTitle });
    activity.createdAt = new Date();
    return activity;
  }

  static createMemberJoined(user: User, household: Household): Activity {
    const activity = new Activity();
    activity.type = 'member_joined';
    activity.action = `joined the household`;
    activity.points = 0;
    activity.entityType = 'household';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({});
    activity.createdAt = new Date();
    return activity;
  }

  static createPointsEarned(user: User, household: Household, points: number, reason: string): Activity {
    const activity = new Activity();
    activity.type = 'points_earned';
    activity.action = `earned ${points} points for ${reason}`;
    activity.points = points;
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ reason });
    activity.createdAt = new Date();
    return activity;
  }

  static createBadgeEarned(user: User, household: Household, badgeName: string): Activity {
    const activity = new Activity();
    activity.type = 'badge_earned';
    activity.action = `earned the "${badgeName}" badge`;
    activity.points = 0;
    activity.entityType = 'badge';
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ badgeName });
    activity.createdAt = new Date();
    return activity;
  }

  static createLevelUp(user: User, household: Household, newLevel: number): Activity {
    const activity = new Activity();
    activity.type = 'level_up';
    activity.action = `reached level ${newLevel}`;
    activity.points = 0;
    activity.user = user;
    activity.household = household;
    activity.metadata = JSON.stringify({ newLevel });
    activity.createdAt = new Date();
    return activity;
  }

  // Cloud sync status for CloudKit-dependent activities
  get requiresCloudSync(): boolean {
    // These activity types should be synced to CloudKit when available
    return [
      'task_completed',
      'task_created', 
      'reward_redeemed',
      'member_joined',
      'points_earned'
    ].includes(this.type);
  }

  get isImportantActivity(): boolean {
    // These are activities that users should be notified about
    return [
      'task_completed',
      'reward_redeemed',
      'challenge_completed',
      'badge_earned',
      'level_up',
      'member_joined'
    ].includes(this.type);
  }
}
