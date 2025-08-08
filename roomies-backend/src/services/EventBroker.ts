import { Response } from 'express';
import { logger } from '@/utils/logger';

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
    for (const [, client] of bucket) {
      try {
        client.res.write(`event: ${event}\n`);
        client.res.write(`data: ${payload}\n\n`);
      } catch (err) {
        logger.warn('Failed to write to SSE client, will drop it', { householdId, clientId: client.id, err });
      }
    }
  }
}

export const eventBroker = new EventBroker();
