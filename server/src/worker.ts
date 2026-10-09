import 'dotenv/config';
import { loadConfig } from './config.js';
import { openDatabase } from './db.js';
import { migrate } from './migrate.js';
import { runMaintenance } from './maintenance.js';

const config = loadConfig({ runWorker: true });
const db = await openDatabase(config);
await migrate(db);
console.log('CDA-Clean worker started');
const tick = () => runMaintenance(db).catch((error) => console.error('[cda-clean] maintenance failed', error));
await tick();
setInterval(tick, 5 * 60 * 1000);
