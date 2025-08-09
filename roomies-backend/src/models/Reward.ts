import { IsNotEmpty, Min } from 'class-validator';
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

import { Household } from './Household';
import { RewardRedemption } from './RewardRedemption';
import { User } from './User';

@Entity('rewards')
export class Reward {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column()
  @IsNotEmpty()
  name!: string;

  @Column({ name: 'reward_description', nullable: true })
  description?: string;

  @Column()
  @Min(1)
  cost!: number; // Points required to redeem

  @Column({ name: 'is_available', default: true })
  isAvailable!: boolean;

  @Column({ name: 'icon_name', default: 'gift' })
  iconName!: string;

  @Column({ default: 'blue' })
  color!: string;

  @Column({ name: 'quantity_available', nullable: true })
  quantityAvailable?: number; // null = unlimited

  @Column({ name: 'times_redeemed', default: 0 })
  timesRedeemed!: number;

  @Column({ name: 'max_per_user', nullable: true })
  maxPerUser?: number; // null = unlimited per user

  @Column({ name: 'expires_at', nullable: true })
  expiresAt?: Date;

  @Column({ name: 'created_by' })
  createdBy!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => Household, household => household.rewards)
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  @ManyToOne(() => User)
  @JoinColumn({ name: 'created_by', referencedColumnName: 'id' })
  creator!: User;

  @OneToMany(() => RewardRedemption, redemption => redemption.reward)
  redemptions!: RewardRedemption[];

  // Helper methods
  get isExpired(): boolean {
    if (!this.expiresAt) return false;
    return new Date() > this.expiresAt;
  }

  get isInStock(): boolean {
    if (!this.quantityAvailable) return true; // Unlimited
    return this.timesRedeemed < this.quantityAvailable;
  }

  get canBeRedeemed(): boolean {
    return this.isAvailable && !this.isExpired && this.isInStock;
  }

  get remainingQuantity(): number | null {
    if (!this.quantityAvailable) return null; // Unlimited
    return Math.max(0, this.quantityAvailable - this.timesRedeemed);
  }

  canUserRedeem(user: User): boolean {
    if (!this.canBeRedeemed) return false;
    if (user.points < this.cost) return false;
    
    if (this.maxPerUser) {
      const userRedemptions = this.getUserRedemptions(user);
      if (userRedemptions >= this.maxPerUser) return false;
    }

    return true;
  }

  getUserRedemptions(user: User): number {
    return this.redemptions?.filter(r => r.redeemedBy.id === user.id).length || 0;
  }

  redeem(user: User): RewardRedemption {
    if (!this.canUserRedeem(user)) {
      throw new Error('Cannot redeem this reward');
    }

    const redemption = new RewardRedemption();
    redemption.reward = this;
    redemption.redeemedBy = user;
    redemption.pointsSpent = this.cost;
    redemption.redeemedAt = new Date();

    // Update counters
    this.timesRedeemed += 1;
    
    // Deduct points from user
    user.points -= this.cost;

    // Check if should be automatically disabled
    if (this.quantityAvailable && this.timesRedeemed >= this.quantityAvailable) {
      this.isAvailable = false;
    }

    return redemption;
  }

  // Status helpers
  get status(): 'available' | 'out_of_stock' | 'expired' | 'disabled' {
    if (!this.isAvailable) return 'disabled';
    if (this.isExpired) return 'expired';
    if (!this.isInStock) return 'out_of_stock';
    return 'available';
  }

  get statusColor(): string {
    switch (this.status) {
      case 'available': return 'green';
      case 'out_of_stock': return 'orange';
      case 'expired': return 'red';
      case 'disabled': return 'gray';
      default: return 'gray';
    }
  }

  // Management methods
  disable(): void {
    this.isAvailable = false;
  }

  enable(): void {
    this.isAvailable = true;
  }

  updateCost(newCost: number): void {
    if (newCost < 1) throw new Error('Cost must be at least 1 point');
    this.cost = newCost;
  }

  updateQuantity(newQuantity: number | null): void {
    this.quantityAvailable = newQuantity || undefined;
    
    // Re-enable if quantity increased and it was disabled due to stock
    if (newQuantity === null || newQuantity > this.timesRedeemed) {
      if (!this.isAvailable && !this.isExpired) {
        this.isAvailable = true;
      }
    }
  }

  updateExpiration(newExpiration: Date | null): void {
    this.expiresAt = newExpiration || undefined;
    
    // Re-enable if expiration was removed or extended
    if (!newExpiration || newExpiration > new Date()) {
      if (!this.isAvailable && this.isInStock) {
        this.isAvailable = true;
      }
    }
  }

  // Analytics helpers
  getPopularityScore(): number {
    return this.timesRedeemed;
  }

  getAverageRedemptionsPerDay(): number {
    const ageInDays = Math.max(1, Math.floor((Date.now() - this.createdAt.getTime()) / (1000 * 60 * 60 * 24)));
    return this.timesRedeemed / ageInDays;
  }

  getRedemptionHistory(): RewardRedemption[] {
    return this.redemptions?.sort((a, b) => b.redeemedAt.getTime() - a.redeemedAt.getTime()) || [];
  }

  // Category helpers (based on cost)
  get category(): 'cheap' | 'moderate' | 'expensive' | 'premium' {
    if (this.cost <= 10) return 'cheap';
    if (this.cost <= 25) return 'moderate';
    if (this.cost <= 50) return 'expensive';
    return 'premium';
  }

  get categoryColor(): string {
    switch (this.category) {
      case 'cheap': return 'green';
      case 'moderate': return 'blue';
      case 'expensive': return 'orange';
      case 'premium': return 'purple';
      default: return 'gray';
    }
  }
}
