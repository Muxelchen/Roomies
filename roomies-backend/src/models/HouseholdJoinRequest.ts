import {
  Entity,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';

import { Household } from './Household';
import { User } from './User';

@Entity('household_join_requests')
export class HouseholdJoinRequest {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @ManyToOne(() => User, { eager: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  @ManyToOne(() => Household, { eager: true, onDelete: 'CASCADE' })
  @JoinColumn({ name: 'household_id' })
  household!: Household;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;
}


