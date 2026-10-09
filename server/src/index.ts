import 'dotenv/config';
import { loadConfig } from './config.js';
import { openDatabase } from './db.js';
import { migrate } from './migrate.js';
import { seed } from './seed.js';
import { createApp } from './app.js';
import { runMaintenance } from './maintenance.js';

const config = loadConfig();
const db = await openDatabase(config);
await migrate(db);
await seed(db);
const app = createApp(db, config);

app.listen(config.port, () => {
  console.log(`CDA-Clean Islamabad API  http://localhost:${config.port}`);
  if (!config.isProd) {
    console.log('Development OTP: 123456');
    console.log('Citizen demo:    03001112233');
    console.log('Supervisor:      SUP-G10 / Clean@123');
    console.log('Field officer:   OFF-G10 / Clean@123');
    console.log('Directorate:     ADM-CDA / Clean@123');
  }
});

if (config.runWorker) {
  setInterval(() => {
    runMaintenance(db).catch((error) => console.error('[cda-clean] maintenance failed', error));
  }, 5 * 60 * 1000);
}
