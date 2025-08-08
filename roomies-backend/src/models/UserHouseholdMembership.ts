import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';
import { User } from './User';
import { Household } from './Household';

export type MemberRole = 'admin' | 'member';

@Entity('user_household_memberships')
export class UserHouseholdMembership {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ type: 'simple-enum', enum: ['admin', 'member'], default: 'member' })
  role!: MemberRole;

  @Column({ name: 'is_active', default: true })
  isActive!: boolean;

  @Column({ name: 'joined_at' })
  joinedAt!: Date;

  @Column({ name: 'left_at', nullable: true })
  leftAt?: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt!: Date;

  // Relationships
  @ManyToOne(() => User, user => user.householdMemberships, { eager: true })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => Household, household => household.memberships, { eager: true })
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  // Helper methods
  get isAdmin(): boolean {
    return this.role === 'admin';
  }

  get isMember(): boolean {
    return this.role === 'member';
  }

  getDaysInHousehold(): number {
    const today = new Date();
    const joinDate = new Date(this.joinedAt);
    const diffTime = Math.abs(today.getTime() - joinDate.getTime());
    return Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  }

  leave(): void {
    this.isActive = false;
    this.leftAt = new Date();
  }

  promoteToAdmin(): void {
    this.role = 'admin';
  }

  demoteToMember(): void {
    this.role = 'member';
  }
}
