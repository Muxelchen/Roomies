import { logger } from '@/utils/logger';
import { Response } from 'express';

export type SSEClient = {
  id: string;
  userId: string;
  ip: string;
  connectedAt: number;
  res: Response;
};

class EventBroker {
  private clientsByHousehold: Map<string, Map<string, SSEClient>> = new Map();
  private totalConnectedClients: number = 0;
  private totalDroppedClients: number = 0;

  addClient(householdId: string, clientId: string, userId: string, ip: string, res: Response): void {
    if (!this.clientsByHousehold.has(householdId)) {
      this.clientsByHousehold.set(householdId, new Map());
    }
    const bucket = this.clientsByHousehold.get(householdId)!;
    bucket.set(clientId, { id: clientId, userId, ip, connectedAt: Date.now(), res });
    this.totalConnectedClients += 1;
    logger.info(`SSE client added: ${clientId} for household ${householdId} (total in household: ${bucket.size}, total: ${this.totalConnectedClients})`);
    // Defensive: ensure response is in flowing mode and socket timeout disabled
    try {
      (res as any).socket?.setTimeout?.(0);
      (res as any).socket?.setNoDelay?.(true);
      (res as any).socket?.setKeepAlive?.(true);
    } catch {}
  }

  removeClient(householdId: string, clientId: string): void {
    const bucket = this.clientsByHousehold.get(householdId);
    if (!bucket) return;
    bucket.delete(clientId);
    if (bucket.size === 0) {
      this.clientsByHousehold.delete(householdId);
    }
    this.totalDroppedClients += 1;
    logger.info(`SSE client removed: ${clientId} for household ${householdId} (remaining in household: ${bucket?.size || 0}, total dropped: ${this.totalDroppedClients})`);
  }

  broadcast(householdId: string, event: string, data: any): void {
    const bucket = this.clientsByHousehold.get(householdId);
    if (!bucket || bucket.size === 0) return;

    const payload = JSON.stringify({ event, data, ts: Date.now() });
    const staleClientIds: string[] = [];
    for (const [clientId, client] of bucket) {
      try {
        // Backpressure guard: skip if client is saturated
        const resAny: any = client.res as any;
        if (typeof resAny.write === 'function') {
          const ok1 = resAny.write(`event: ${event}\n`);
          const ok2 = resAny.write(`data: ${payload}\n\n`);
          if (ok1 === false || ok2 === false) {
            // If write returns false, stream is backed up; do not force
            logger.warn('SSE backpressure: skipping write for client', { householdId, clientId });
          }
        }
      } catch (err) {
        logger.warn('Failed to write to SSE client, will drop it', { householdId, clientId: client.id, err });
        staleClientIds.push(clientId);
      }
    }
    // Cleanup stale clients to prevent memory leaks/backpressure buildup
    for (const clientId of staleClientIds) {
      try {
        bucket.delete(clientId);
        this.totalDroppedClients += 1;
      } catch {}
    }
    if (bucket.size === 0) {
      this.clientsByHousehold.delete(householdId);
    }
  }

  // Metrics and limits helpers
  getHouseholdClientCount(householdId: string): number {
    return this.clientsByHousehold.get(householdId)?.size || 0;
  }

  getUserClientCount(householdId: string, userId: string): number {
    const bucket = this.clientsByHousehold.get(householdId);
    if (!bucket) return 0;
    let count = 0;
    for (const [, client] of bucket) {
      if (client.userId === userId) count++;
    }
    return count;
  }

  getMetrics() {
    let households = 0;
    let total = 0;
    for (const [, bucket] of this.clientsByHousehold) {
      households++;
      total += bucket.size;
    }
    return {
      households,
      total,
      totalConnected: this.totalConnectedClients,
      totalDropped: this.totalDroppedClients
    };
  }
}

export const eventBroker = new EventBroker();
