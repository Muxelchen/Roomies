import 'reflect-metadata';
import { rollbackMigrations } from './migrate';

(async () => {
  await rollbackMigrations();
  // eslint-disable-next-line no-process-exit
  process.exit(0);
})().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  // eslint-disable-next-line no-process-exit
  process.exit(1);
});

