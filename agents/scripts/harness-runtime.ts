import { createHash } from 'node:crypto';
import { spawn, spawnSync } from 'node:child_process';
import { mkdir, mkdtemp, readFile, realpath, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { argumentsFor, loadCatalog, resolveConnection, type Selection } from './model-connection';

export function renderRuntime(selection: Selection) {
  const { connection: c } = selection;
  const common = { fingerprint: selection.fingerprint, runtime: selection.runtime, engine: selection.engine };
  if (selection.runtime === 'claude-code') {
    return {
      ...common,
      args: ['--print'],
      env: {
        ANTHROPIC_BASE_URL: c.base_url,
        ANTHROPIC_AUTH_TOKEN: 'unused',
        ANTHROPIC_MODEL: c.models.main.id,
        ANTHROPIC_SMALL_FAST_MODEL: (c.models.small ?? c.models.main).id,
        CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC: '1',
        CLAUDE_CODE_DISABLE_NONSTREAMING_FALLBACK: '1',
        CLAUDE_CODE_AUTO_COMPACT_WINDOW: String(c.models.main.context_window),
      },
      patch: null,
    };
  }
  // The base-backed headless profile already supplies the dormant pi-ai row.
  const route = 'harness-gateway';
  const models = [...new Map([c.models.main, c.models.small].filter(Boolean).map(m => [m!.id, m!])).values()];
  return {
    ...common,
    args: ['--profile', 'headless', '--json'],
    env: { HARNESS_GATEWAY_TOKEN: 'unused', DSH_MAX_TOKENS_AS_SUCCESS: 'false' },
    patch: [
      { id: 'agent-default-model', config: { provider: route, model: c.models.main.id } },
      { id: 'llm-pi-ai', config: { providers: {
        [route]: { api: c.transport, baseURL: c.base_url, apiKeyEnv: 'HARNESS_GATEWAY_TOKEN',
          retryPolicy: { mode: 'normal', maxRetries: 0 },
          models: models.map(m => ({ id: m.id, contextWindow: m.context_window, maxTokens: m.max_output_tokens })),
        },
      } } },
      { id: 'session-title-llm', disabled: true },
      { id: 'llm-deepseek', disabled: true },
      { id: 'llm-deepseek-account', disabled: true },
    ],
  };
}

// Do not forward ambient provider keys, credential homes, proxy settings, or
// runtime option overrides. This is configuration hygiene, not an OS sandbox.
export function launchEnvironment(source: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const result: NodeJS.ProcessEnv = {};
  for (const key of ['PATH', 'HOME', 'USER', 'LOGNAME', 'LANG', 'LC_ALL', 'TERM', 'TMPDIR', 'SYSTEMROOT']) {
    if (source[key] !== undefined) result[key] = source[key];
  }
  return result;
}

export function checkVersion(command: string, expected: string, env: NodeJS.ProcessEnv) {
  const result = spawnSync(command, ['--version'], { env, encoding: 'utf8', timeout: 5000, maxBuffer: 65536 });
  if (result.error || result.status !== 0) throw new Error('Runtime version probe failed');
  const versions = result.stdout.match(/\b\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?\b/g) ?? [];
  if (!versions.includes(expected)) throw new Error('Runtime version does not match the selected pin');
}

export async function launch(selection: Selection, options: { cwd: string; state: string; task: string; env?: NodeJS.ProcessEnv; timeoutMs?: number }) {
  selection = structuredClone(selection);
  const { fingerprint, ...binding } = selection;
  const actual = `sha256:${createHash('sha256').update(JSON.stringify(binding)).digest('hex')}`;
  if (actual !== fingerprint) throw new Error('Selection fingerprint does not match its contents');
  const timeoutMs = options.timeoutMs ?? 600_000;
  if (!Number.isSafeInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 3_600_000) throw new Error('Invalid execution timeout');
  if (!options.task.trim()) throw new Error('Task must not be empty');
  if (!options.state.startsWith('/')) throw new Error('State directory must be absolute');
  const cwd = await realpath(options.cwd);
  const rendered = renderRuntime(selection);
  const env = launchEnvironment(options.env ?? process.env);
  // Probe with a private temporary HOME and config locations as --version may
  // itself create native state. The real user home is not used for the probe.
  await mkdir(options.state, { recursive: true, mode: 0o700 });
  const directory = await mkdtemp(join(options.state, 'run-'));
  await mkdir(join(directory, 'home'), { mode: 0o700 });
  env.HOME = join(directory, 'home');
  env.XDG_CONFIG_HOME = join(directory, 'config');
  env.XDG_DATA_HOME = join(directory, 'data');
  env.XDG_STATE_HOME = join(directory, 'state');
  env.XDG_CACHE_HOME = join(directory, 'cache');
  env.DSH_HOME = join(directory, 'dsh');
  env.CLAUDE_CONFIG_DIR = join(directory, 'claude');
  checkVersion(rendered.engine.command, rendered.engine.version, env);
  Object.assign(env, rendered.env);
  let args = [...rendered.args];
  if (rendered.patch) {
    const patch = join(directory, 'gateway.patch.json');
    await writeFile(patch, JSON.stringify(rendered.patch, null, 2), { mode: 0o600, flag: 'wx' });
    args = ['--patch', patch, ...args];
  }
  await writeFile(join(directory, 'binding.json'), JSON.stringify({ ...selection, cwd, timeout_ms: timeoutMs, status: 'prepared' }, null, 2), { mode: 0o600, flag: 'wx' });
  // New native sessions only. No arbitrary native flags can bypass the route.
  args.push('--', options.task);
  const code = await new Promise<number>((accept, reject) => {
    const child = spawn(rendered.engine.command, args, { env, cwd, stdio: 'inherit', detached: process.platform !== 'win32' });
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
  await writeFile(join(directory, 'outcome.json'), JSON.stringify({ exit_code: code, task_success: 'unverified' }), { mode: 0o600, flag: 'wx' });
  // Native exit 0 is not Core Evidence, Human Gate approval, or publication.
  return { code, directory };
}

if (import.meta.main) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const flags = argumentsFor(args, ['config', 'profile', 'group', 'runtime', 'cwd', 'state', 'task-file', 'execute']);
    if (!flags.config || !flags.profile || !flags.group) throw new Error('Explicit config, profile and group are required');
    const selection = resolveConnection(await loadCatalog(flags.config), { profile: flags.profile, group: flags.group, runtime: flags.runtime });
    if (command === 'plan' && !flags.execute && !flags.state && !flags['task-file']) {
      console.log(JSON.stringify({ ...renderRuntime(selection), cwd: resolve(flags.cwd ?? '.'), execution: 'not_started', timeout_seconds: 600 }, null, 2));
    } else if (command === 'run' && flags.execute === 'true' && flags.state && flags['task-file']) {
      const result = await launch(selection, { cwd: flags.cwd ?? '.', state: flags.state, task: await readFile(flags['task-file'], 'utf8') });
      console.error(JSON.stringify({ fingerprint: selection.fingerprint, ...result }));
      process.exitCode = result.code;
    } else throw new Error('Use plan, or run --execute true --state <absolute-dir> --task-file <file>');
  } catch (error) {
    console.error((error as Error).message);
    process.exitCode = 2;
  }
}
