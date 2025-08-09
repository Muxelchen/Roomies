import { logger } from '@/utils/logger';
import { Response } from 'express';

export type SSEClient = {
  id: string;
  res: Response;
};

class EventBroker {
  private clientsByHousehold: Map<string, Map<string, SSEClient>> = new Map();

  addClient(householdId: string, clientId: string, res: Response): void {
    if (!this.clientsByHousehold.has(householdId)) {
      this.clientsByHousehold.set(householdId, new Map());
    }
    const bucket = this.clientsByHousehold.get(householdId)!;
    bucket.set(clientId, { id: clientId, res });
    logger.info(`SSE client added: ${clientId} for household ${householdId} (total: ${bucket.size})`);
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
    logger.info(`SSE client removed: ${clientId} for household ${householdId} (remaining: ${bucket?.size || 0})`);
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
      } catch {}
    }
    if (bucket.size === 0) {
      this.clientsByHousehold.delete(householdId);
    }
  }
}

export const eventBroker = new EventBroker();
