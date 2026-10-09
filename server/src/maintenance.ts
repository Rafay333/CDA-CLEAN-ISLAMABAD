import type { Db } from './db.js';
import { addEvent, listSupervisors, notifyUsers } from './cases.js';

export async function runMaintenance(db: Db): Promise<void> {
  const now = new Date();
  await db.transaction(async (tx) => {
    const ack = await tx.query<{ id: string; zone_id: string; case_number: string }>(
      `SELECT id, zone_id, case_number FROM cases
       WHERE status = 'submitted' AND ack_breached = FALSE AND ack_due_at IS NOT NULL AND ack_due_at < $1`,
      [now],
    );
    for (const row of ack.rows) {
      await tx.query(`UPDATE cases SET ack_breached = TRUE, updated_at = NOW() WHERE id = $1`, [row.id]);
      await notifyUsers(
        tx,
        await listSupervisors(tx, row.zone_id),
        row.id,
        { title: 'Review is overdue', body: `${row.case_number} is still waiting to be accepted.` },
        { title: 'جائزہ دیر سے ہو رہا ہے', body: `${row.case_number} ابھی تک قبول نہیں ہوئی۔` },
      );
    }

    const late = await tx.query<{ id: string; zone_id: string; case_number: string }>(
      `SELECT id, zone_id, case_number FROM cases
       WHERE status IN ('accepted', 'assigned', 'in_progress', 'reopened')
         AND sla_breached = FALSE AND sla_due_at IS NOT NULL AND sla_due_at < $1`,
      [now],
    );
    for (const row of late.rows) {
      await tx.query(`UPDATE cases SET sla_breached = TRUE, updated_at = NOW() WHERE id = $1`, [row.id]);
      await notifyUsers(
        tx,
        await listSupervisors(tx, row.zone_id),
        row.id,
        { title: 'Resolve time exceeded', body: `${row.case_number} is past its resolve time.` },
        { title: 'حل کا وقت گزر گیا', body: `${row.case_number} مقررہ وقت سے آگے ہے۔` },
      );
    }

    const cutoff = new Date(now.getTime() - 48 * 60 * 60 * 1000);
    const done = await tx.query<{ id: string; case_number: string; reporter_id: string; language: string }>(
      `SELECT c.id, c.case_number, c.reporter_id, u.language
       FROM cases c
       JOIN users u ON u.id = c.reporter_id
       WHERE c.status = 'resolved' AND c.resolved_at IS NOT NULL AND c.resolved_at < $1`,
      [cutoff],
    );
    for (const row of done.rows) {
      await tx.query(`UPDATE cases SET status = 'closed', updated_at = NOW() WHERE id = $1`, [row.id]);
      await addEvent(tx, row.id, null, 'resolved', 'closed', 'Closed automatically after 48 hours.');
      await notifyUsers(
        tx,
        [{ id: row.reporter_id, language: row.language }],
        row.id,
        { title: 'Report closed', body: `${row.case_number} closed after 48 hours with no dispute.` },
        { title: 'شکایت بند ہو گئی', body: `${row.case_number} 48 گھنٹے بعد بند ہو گئی۔` },
      );
    }
  });
}
