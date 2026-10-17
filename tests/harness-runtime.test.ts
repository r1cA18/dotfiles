import { afterEach, expect, test } from 'bun:test';
import { mkdtempSync, readFileSync, rmSync, writeFileSync, readdirSync, existsSync, mkdirSync, readlinkSync, realpathSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { launch, launchEnvironment, renderRuntime } from '../agents/scripts/harness-runtime';
import { resolveConnection, validateCatalog, type Runtime } from '../agents/scripts/model-connection';
import example from '../agents/model-connections/example.json';
const roots: string[] = [];
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });
function fixture(runtime: Runtime = 'dsh', body = '') {
  const root = mkdtempSync(join(tmpdir(), 'harness-launch-')); roots.push(root);
  const capture = join(root, 'capture.json'); const command = join(root, 'fake-native');
  writeFileSync(command, `#!${process.execPath}\nimport {writeFileSync} from 'node:fs';\nif (process.argv[2] === '--version') { console.log('1.2.3'); process.exit(0); }\nwriteFileSync(${JSON.stringify(capture)}, JSON.stringify({args:process.argv.slice(2),env:process.env,cwd:process.cwd()}));\n${body}\n`, { mode: 0o755 });
  const catalog = validateCatalog(example); catalog.connections[0].billing = 'api'; catalog.runtimes[runtime] = { command, version: '1.2.3' };
  const selection = resolveConnection(catalog, { profile: 'development', group: 'personal', runtime });
  const options = { cwd: root, state: join(root, 'state'), task: '--dangerously-skip-permissions $(touch SHOULD_NOT_EXIST)', env: {
    PATH: process.env.PATH, HOME: root, OPENAI_API_KEY: 'ambient-secret', ANTHROPIC_API_KEY: 'ambient-secret',
    DSH_HOME: '/must-not-use', CLAUDE_CONFIG_DIR: '/must-not-use', ANTHROPIC_BASE_URL: 'https://wrong.invalid',
  } };
  return { root, capture, selection, options, catalog };
}
test('dsh rendering uses the base pi-ai route and the chosen model capacities', () => {
  const { selection } = fixture(); const rendered = renderRuntime(selection);
  const route = (rendered.patch![1] as any).config.providers['harness-gateway'];
  expect(route.api).toBe('anthropic-messages');
  expect(route.baseURL).toBe(selection.connection.base_url);
  expect(route.models[0].contextWindow).toBe(selection.connection.models.main.context_window);
  expect(route.retryPolicy.maxRetries).toBe(0);
  expect(rendered.args).toEqual(['--profile', 'headless', '--json']);
});
test('Claude rendering preserves separate main and small model roles', () => {
  const { selection } = fixture('claude-code'); const rendered = renderRuntime(selection);
  expect(rendered.patch).toBe(null);
  expect(rendered.env.ANTHROPIC_MODEL).toBe(selection.connection.models.main.id);
  expect(rendered.env.ANTHROPIC_SMALL_FAST_MODEL).toBe(selection.connection.models.small!.id);
});
test('environment allowlist removes ambient credentials and runtime overrides', () => {
  expect(launchEnvironment({ PATH: '/bin', HOME: '/home/test', OPENAI_API_KEY: 'x', NODE_OPTIONS: '--inspect', DSH_HOME: '/x', HTTPS_PROXY: 'secret' })).toEqual({ PATH: '/bin', HOME: '/home/test' });
});
for (const runtime of ['dsh', 'claude-code'] as const) {
  test(`${runtime} launches only a fake binary with private state and literal task arguments`, async () => {
    const f = fixture(runtime); const result = await launch(f.selection, f.options);
    expect(result.code).toBe(0);
    const capture = JSON.parse(readFileSync(f.capture, 'utf8'));
    expect(capture.args.slice(-2)).toEqual(['--', f.options.task]);
    expect(capture.env.OPENAI_API_KEY).toBeUndefined();
    expect(capture.env.ANTHROPIC_API_KEY).toBeUndefined();
    expect(capture.env.HOME).toBe(join(result.directory, 'home'));
    expect(capture.env.DSH_HOME).toBe(join(result.directory, 'dsh'));
    expect(capture.env.CLAUDE_CONFIG_DIR).toBe(join(result.directory, 'claude'));
    expect(existsSync(join(f.root, 'SHOULD_NOT_EXIST'))).toBe(false);
    expect(JSON.parse(readFileSync(join(result.directory, 'binding.json'), 'utf8')).fingerprint).toBe(f.selection.fingerprint);
    expect(JSON.parse(readFileSync(join(result.directory, 'outcome.json'), 'utf8')).task_success).toBe('unverified');
    if (runtime === 'dsh') expect(JSON.parse(readFileSync(capture.args[1], 'utf8'))).toEqual(renderRuntime(f.selection).patch);
  });
}
test('version mismatch rejects before the task process starts', async () => {
  const f = fixture(); f.catalog.runtimes.dsh.version = '9.9.9';
  const selection = resolveConnection(f.catalog, { profile: 'development', group: 'personal' });
  await expect(launch(selection, f.options)).rejects.toThrow('version');
  expect(existsSync(f.capture)).toBe(false);
});
test('native failure remains a failure and is not retried', async () => {
  const f = fixture('dsh', 'process.exit(7);');
  expect((await launch(f.selection, f.options)).code).toBe(7);
  expect(readdirSync(f.options.state)).toHaveLength(1);
});
test('deadline terminates the process group including a running descendant', async () => {
  const f = fixture('dsh'); const pidFile = join(f.root, 'child.pid');
  const command = f.selection.engine.command;
  writeFileSync(command, `#!${process.execPath}\nimport {spawn} from 'node:child_process';\nimport {writeFileSync} from 'node:fs';\nif(process.argv[2] === '--version'){console.log('1.2.3');process.exit(0);}\nconst child=spawn(${JSON.stringify(process.execPath)},['-e','setInterval(()=>{},1000)'],{stdio:'ignore'});\nwriteFileSync(${JSON.stringify(pidFile)},String(child.pid));\nsetInterval(()=>{},1000);\n`, { mode: 0o755 });
  const result = await launch(f.selection, { ...f.options, timeoutMs: 1000 });
  expect(result.code).toBe(3);
  const pid = Number(readFileSync(pidFile, 'utf8'));
  // A killed process can briefly remain a zombie; it must not remain running.
  const ps = Bun.spawnSync(['ps', '-o', 'stat=', '-p', String(pid)]);
  const status = ps.stdout.toString().trim();
  expect(status === '' || status.startsWith('Z')).toBe(true);
});
test('CLI plan performs no writes and run requires explicit execution consent', () => {
  const f = fixture(); const config = join(f.root, 'connections.json');
  writeFileSync(config, JSON.stringify(f.catalog));
  const cli = resolve('agents/scripts/harness-runtime.ts');
  const args = ['--config', config, '--profile', 'development', '--group', 'personal'];
  const before = readdirSync(f.root);
  const plan = Bun.spawnSync([process.execPath, cli, 'plan', ...args]);
  expect(plan.exitCode).toBe(0);
  expect(JSON.parse(plan.stdout.toString()).execution).toBe('not_started');
  expect(readdirSync(f.root)).toEqual(before);
  expect(Bun.spawnSync([process.execPath, cli, 'run', ...args]).exitCode).toBe(2);
  expect(readdirSync(f.root)).toEqual(before);
});
test('empty tasks and invalid execution limits fail before any state is written', async () => {
  const f = fixture();
  await expect(launch(f.selection, { ...f.options, task: '  ' })).rejects.toThrow();
  await expect(launch(f.selection, { ...f.options, timeoutMs: -1 })).rejects.toThrow();
  expect(existsSync(f.options.state)).toBe(false);
});

test('a mutated selection cannot reuse a previous fingerprint', async () => {
  const f = fixture(); f.selection.connection.account_ref = 'another';
  await expect(launch(f.selection, f.options)).rejects.toThrow('fingerprint');
  expect(existsSync(f.options.state)).toBe(false);
});

for (const runtime of ['dsh', 'claude-code'] as const) {
  test(`${runtime} receives only explicitly supplied shared instructions and skills`, async () => {
    const f = fixture(runtime);
    const instructions = join(f.root, 'shared.md'); const skills = join(f.root, 'shared-skills');
    writeFileSync(instructions, 'Shared instruction fixture'); mkdirSync(skills);
    const result = await launch(f.selection, { ...f.options, assets: { instructionsFile: instructions, skillsDirectory: skills } });
    const native = join(result.directory, runtime === 'dsh' ? 'dsh' : 'claude');
    expect(readFileSync(join(native, runtime === 'dsh' ? 'AGENTS.md' : 'CLAUDE.md'), 'utf8')).toBe('Shared instruction fixture');
    expect(readlinkSync(join(native, 'skills'))).toBe(realpathSync(skills));
    expect(JSON.parse(readFileSync(join(result.directory, 'binding.json'), 'utf8')).assets.instructions_sha256).toMatch(/^[a-f0-9]{64}$/);
  });
}

test('legacy catalogs cannot bypass subscription support checks', async () => {
  const f = fixture(); f.catalog.connections[0].billing = 'subscription';
  const selection = resolveConnection(f.catalog, { profile: 'development', group: 'personal' });
  expect(() => renderRuntime(selection)).toThrow('subscription_adapter_unimplemented');
  await expect(launch(selection, f.options)).rejects.toThrow('subscription_adapter_unimplemented');
  expect(existsSync(f.options.state)).toBe(false);
});
