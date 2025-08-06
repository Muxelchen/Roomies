import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';
import { User } from './User';
import { Reward } from './Reward';

@Entity('reward_redemptions')
export class RewardRedemption {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'points_spent' })
  pointsSpent!: number;

  @Column({ name: 'redeemed_at' })
  redeemedAt!: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  // Relationships
  @ManyToOne(() => User, user => user.rewardRedemptions)
  @JoinColumn({ name: 'redeemed_by' })
  redeemedBy!: User;

  @ManyToOne(() => Reward, reward => reward.redemptions)
  @JoinColumn({ name: 'reward_id' })
  reward!: Reward;

  // Helper methods
  get redemptionAge(): string {
    const now = new Date();
    const diffMs = now.getTime() - this.redeemedAt.getTime();
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
    return `${Math.floor(diffDays / 30)} months ago`;
  }

  get wasGoodDeal(): boolean {
    // Simple heuristic: if the user got a good points-to-value ratio
    return this.pointsSpent <= 20; // Assuming rewards under 20 points are good deals
  }
}
