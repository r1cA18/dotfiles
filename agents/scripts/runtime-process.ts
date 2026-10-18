import { spawn } from 'node:child_process';

// Shared bounded process-group lifecycle for native runtime adapters.
export async function runCommand(command: string, args: string[], options: { env: NodeJS.ProcessEnv; cwd: string; timeoutMs: number; stdio?: 'inherit' | 'ignore' }) {
  const { env, cwd, timeoutMs } = options;
  return await new Promise<number>((accept, reject) => {
    const child = spawn(command, args, { env, cwd, stdio: options.stdio ?? 'inherit', detached: process.platform !== 'win32' });
    let escalation: ReturnType<typeof setTimeout> | undefined;
    let cancelled = false;
    const signalGroup = (signal: NodeJS.Signals) => {
      try {
        if (child.pid && process.platform !== 'win32') process.kill(-child.pid, signal);
        else child.kill(signal);
      } catch (error) { if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error; }
    };
    const cancel = () => {
      if (cancelled) return;
      cancelled = true;
      signalGroup('SIGTERM');
      escalation = setTimeout(() => signalGroup('SIGKILL'), 2000);
    };
    const deadline = setTimeout(cancel, timeoutMs);
    process.on('SIGINT', cancel); process.on('SIGTERM', cancel);
    const dispose = () => {
      clearTimeout(deadline);
      if (escalation) clearTimeout(escalation);
      process.off('SIGINT', cancel); process.off('SIGTERM', cancel);
    };
    child.once('error', error => { dispose(); reject(error); });
    child.once('close', (exit, signal) => {
      // Also reap descendants if the parent exits before the grace period.
      signalGroup('SIGKILL');
      dispose(); accept(cancelled || signal ? 3 : exit ?? 3);
    });
  });
}
