import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn
} from 'typeorm';

import { User } from './User';

@Entity('refresh_tokens')
export class RefreshToken {
  @PrimaryGeneratedColumn('uuid')
  id!: string;

  @Column({ name: 'token_hash', unique: true })
  tokenHash!: string;

  @Column({ name: 'expires_at' })
  expiresAt!: Date;

  @Column({ name: 'revoked_at', nullable: true })
  revokedAt?: Date | null;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @ManyToOne(() => User, user => user.rewardRedemptions, { eager: true })
  @JoinColumn({ name: 'user_id' })
  user!: User;

  get isExpired(): boolean {
    return new Date().getTime() > new Date(this.expiresAt).getTime();
  }

  get isActive(): boolean {
    return !this.revokedAt && !this.isExpired;
  }
}


