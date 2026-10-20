import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createInterface } from 'node:readline';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ApiError } from './errors.js';

/** `size` is the detected face width in pixels (0 when no single face was found). */
export type EncodeResult = { count: number; size: number; encoding: number[] | null; error?: string | null };
export type BurstResult =
  | { ok: true; encodings: number[][]; sizes: number[]; feat: number[]; motion: number; blink: number }
  | { ok: false; error: string };

type Pending = { resolve: (value: Record<string, unknown>) => void; reject: (error: Error) => void };

const here = path.dirname(fileURLToPath(import.meta.url));

export class FaceWorker {
  private child: ChildProcessWithoutNullStreams | null = null;
  private pending = new Map<number, Pending>();
  private chain: Promise<unknown> = Promise.resolve();
  private seq = 1;
  private ready: Promise<void> | null = null;

  constructor(private readonly modelsDir: string) {}

  encode(file: string): Promise<EncodeResult> {
    return this.call({ op: 'encode', path: file });
  }

  burst(files: string[]): Promise<BurstResult> {
    return this.call({ op: 'burst', paths: files });
  }

  private call<T>(body: Record<string, unknown>): Promise<T> {
    const run = this.chain.then(() => this.send<T>(body));
    this.chain = run.then(() => undefined, () => undefined);
    return run;
  }

  private async send<T>(body: Record<string, unknown>): Promise<T> {
    await this.ensure();
    const child = this.child;
    if (!child) throw new ApiError(500, 'FACE', 'Face recognition is not running.');
    const id = this.seq++;
    const result = new Promise<Record<string, unknown>>((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    child.stdin.write(JSON.stringify({ id, ...body }) + '\n');
    const row = await result;
    if (body.op === 'encode' && typeof row.error === 'string' && row.error) {
      console.error('[face] encode failed:', row.error);
      throw new ApiError(500, 'FACE', 'Face recognition failed on the server: ' + row.error);
    }
    return row as T;
  }

  private ensure(): Promise<void> {
    if (this.child && !this.child.killed) return this.ready ?? Promise.resolve();
    const candidates = [
      path.resolve(here, '../face-worker/bin/x64/Release/net8.0/FaceWorker.dll'),
      path.resolve(here, '../face-worker/bin/Release/net8.0/FaceWorker.dll'),
    ];
    const dll = candidates.find((file) => existsSync(file));
    if (!dll) {
      return Promise.reject(new ApiError(500, 'FACE', 'Face recognition is not built. From the server folder run: dotnet build face-worker -c Release'));
    }
    let child: ChildProcessWithoutNullStreams;
    try {
      child = spawn('dotnet', [dll], {
        env: { ...process.env, FACE_MODELS: this.modelsDir },
        stdio: ['pipe', 'pipe', 'pipe'],
        windowsHide: true,
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return Promise.reject(new ApiError(500, 'FACE', 'Could not start face recognition. ' + message));
    }
    this.child = child;
    this.ready = new Promise((resolve, reject) => {
      const fail = (message: string) => {
        this.child = null;
        reject(new ApiError(500, 'FACE', message));
      };
      child.once('error', (error) => fail('Could not start face recognition. ' + error.message));
      child.once('exit', (code) => {
        const waiters = [...this.pending.values()];
        this.pending.clear();
        this.child = null;
        for (const waiter of waiters) waiter.reject(new Error('Face recognition stopped.'));
        fail(`Face recognition stopped (${code ?? 'no code'}). Build it with: dotnet build face-worker -c Release`);
      });
      const lines = createInterface({ input: child.stdout });
      const onLine = (line: string) => {
        let row: Record<string, unknown>;
        try { row = JSON.parse(line) as Record<string, unknown>; }
        catch { return; }
        if (row.ready === true) {
          lines.removeListener('line', onReady);
          lines.on('line', (next) => {
            try {
              const parsed = JSON.parse(next) as Record<string, unknown>;
              const id = Number(parsed.id);
              const waiter = this.pending.get(id);
              if (!waiter) return;
              this.pending.delete(id);
              waiter.resolve(parsed);
            } catch { /* ignore a broken line */ }
          });
          resolve();
          return;
        }
        if (row.ready === false) fail(typeof row.error === 'string' ? row.error : 'Face models did not load.');
      };
      const onReady = (line: string) => onLine(line);
      lines.on('line', onReady);
      child.stderr.on('data', () => undefined);
    });
    return this.ready;
  }
}

export function defaultModelsDir(): string {
  return path.resolve(here, '../../AttendanceSystem/Server/models');
}
