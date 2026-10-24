import { expect, test } from 'bun:test';
import { doctorProfiles, resolveProfile, resolveCoreSelection, validateManifest, validateBindings } from '../agents/scripts/harness-profile';
import { launch, renderRuntime } from '../agents/scripts/harness-runtime';
import { mkdtempSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

function fixture(runtime = 'codex', provider = 'openai') {
  return {
    manifest: {
      schema_version: 1, default_runtime: 'dsh',
      runtimes: { dsh: { version: '0.2.1-rc.2' }, codex: { version: '0.163.0' }, 'claude-code': { version: '2.1.310' } },
      connections: [{ id: 'personal-native', group: 'personal', provider, account_ref: 'owner-native', billing: 'subscription', transport: 'native', models: { main: { id: 'test-model', context_window: 10000, max_output_tokens: 1000 } } }],
      profiles: [{ id: 'coding', connection: 'personal-native', runtime }],
    },
    bindings: { schema_version: 1, commands: { codex: 'codex', 'claude-code': 'claude', dsh: 'dsh' }, accounts: [{ connection: 'personal-native', group: 'personal', account_ref: 'owner-native', config_home: '/private/operator/native-home', core_account: { host: 'worker-one', id: `sha256:${'a'.repeat(64)}` } }] },
    options: { group: 'personal', profile: 'coding' },
  };
}

test('native profiles preserve portable identity while resolving host-local login references', () => {
  const f = fixture();
  const manifest = validateManifest(f.manifest);
  const bindings = validateBindings(f.bindings);
  const first = resolveProfile(manifest, bindings, f.options);
  const report = doctorProfiles(manifest, bindings, f.options)[0];
  expect(report.status).toBe('ready');
  expect(report.credentials_checked).toBe(false);
  expect(report.inference_checked).toBe(false);
  expect(first.connection.transport).toBe('native');
  expect((first.connection as any).config_home).toBe(f.bindings.accounts[0].config_home);
  expect('base_url' in first.connection).toBe(false);
  f.bindings.accounts[0].config_home = '/other/device/native-home';
  f.bindings.accounts[0].core_account.host = 'worker-two';
  const second = resolveProfile(manifest, validateBindings(f.bindings), f.options);
  expect(second.fingerprint).not.toBe(first.fingerprint);
  expect(doctorProfiles(manifest, validateBindings(f.bindings), f.options)[0].manifest_fingerprint).toBe(report.manifest_fingerprint);
});

test('native transport supports only the explicitly matching runtime and provider', () => {
  for (const runtime of ['dsh', 'codex', 'claude-code']) {
    for (const provider of ['openai', 'anthropic']) {
      const f = fixture(runtime, provider);
      const supported = new Set(['codex:openai', 'claude-code:anthropic']).has(`${runtime}:${provider}`);
      const report = doctorProfiles(validateManifest(f.manifest), validateBindings(f.bindings), f.options)[0];
      expect(report.status).toBe(supported ? 'ready' : 'blocked');
      if (supported) {
        const rendered = renderRuntime(resolveProfile(validateManifest(f.manifest), validateBindings(f.bindings), f.options));
        expect(rendered.args).toEqual(runtime === 'codex' ? ['exec', '--json', '--model', 'test-model'] : ['--print', '--model', 'test-model']);
        expect(rendered.env).toEqual({ [runtime === 'codex' ? 'CODEX_HOME' : 'CLAUDE_CONFIG_DIR']: f.bindings.accounts[0].config_home });
        expect(rendered.patch).toBeNull();
      } else {
        expect(() => resolveProfile(validateManifest(f.manifest), validateBindings(f.bindings), f.options)).toThrow('native_route_unsupported');
      }
    }
  }
});

test('JSON roundtrips preserve native selections and changed Core identities change fingerprints', () => {
  for (const home of ['/private/config/home', '/private/config home', "/private/owner's/config"]) {
    const f = fixture(); f.bindings.accounts[0].config_home = home;
    const manifest = validateManifest(f.manifest); const bindings = validateBindings(f.bindings);
    const first = resolveProfile(manifest, bindings, f.options);
    expect(resolveProfile(validateManifest(JSON.parse(JSON.stringify(manifest))), validateBindings(JSON.parse(JSON.stringify(bindings))), f.options)).toEqual(first);
    f.bindings.accounts[0].core_account.id = `sha256:${'b'.repeat(64)}`;
    expect(resolveProfile(manifest, validateBindings(f.bindings), f.options).fingerprint).not.toBe(first.fingerprint);
  }
});

test('native config homes cannot represent another logical account scope', () => {
  const f = fixture();
  f.manifest.connections.push({ ...f.manifest.connections[0], id: 'other', group: 'work', account_ref: 'work' });
  f.bindings.accounts.push({ ...f.bindings.accounts[0], connection: 'other', group: 'work', account_ref: 'work', config_home: '/private/operator/./native-home' });
  expect(doctorProfiles(validateManifest(f.manifest), validateBindings(f.bindings), f.options)[0].issues[0].code).toBe('native_scope_conflict');
  expect(() => resolveProfile(validateManifest(f.manifest), validateBindings(f.bindings), f.options)).toThrow();
});

test('native runs use selected login references with private version probes and literal model/task arguments', async () => {
  for (const [runtime, provider] of [['codex', 'openai'], ['claude-code', 'anthropic']]) {
    const root = mkdtempSync(join(tmpdir(), 'native-profile-launch-'));
    try {
      const f = fixture(runtime, provider);
      const home = join(root, 'existing-home'); mkdirSync(home);
      writeFileSync(join(home, 'keep.json'), 'synthetic native state');
      f.bindings.accounts[0].config_home = home;
      const command = join(root, 'native');
      const version = f.manifest.runtimes[runtime as 'codex' | 'claude-code'].version;
      const output = join(root, 'observed.json'); const probe = join(root, 'probe.json');
      writeFileSync(command, `#!${process.execPath}\nimport {writeFileSync} from 'node:fs';\nconst value={args:process.argv.slice(2),env:process.env};\nif(process.argv[2]==='--version'){writeFileSync(${JSON.stringify(probe)},JSON.stringify(value));console.log(${JSON.stringify(version)});}else{writeFileSync(${JSON.stringify(output)},JSON.stringify(value));}\n`, { mode: 0o700 });
      f.bindings.commands[runtime as 'codex' | 'claude-code'] = command;
      const selection = resolveProfile(validateManifest(f.manifest), validateBindings(f.bindings), f.options);
      const task = '-literal $(touch NOT_A_COMMAND)';
      const result = await launch(selection, { cwd: root, state: join(root, 'state'), task, env: { PATH: process.env.PATH, HOME: root, ANTHROPIC_API_KEY: 'ambient-sentinel', CODEX_HOME: '/wrong/account' } });
      expect(result.code).toBe(0);
      const observed = JSON.parse(readFileSync(output, 'utf8'));
      const versionProbe = JSON.parse(readFileSync(probe, 'utf8'));
      const variable = runtime === 'codex' ? 'CODEX_HOME' : 'CLAUDE_CONFIG_DIR';
      expect(observed.env[variable]).toBe(home);
      expect(versionProbe.env[variable]).not.toBe(home);
      expect(observed.env.HOME).not.toBe(root);
      expect(observed.env.ANTHROPIC_API_KEY).toBeUndefined();
      expect(observed.args.slice(-2)).toEqual(['--', task]);
      expect(observed.args[observed.args.indexOf('--model') + 1]).toBe('test-model');
      expect(readdirSync(home)).toEqual(['keep.json']);
      expect(readFileSync(join(home, 'keep.json'), 'utf8')).toBe('synthetic native state');
    } finally { rmSync(root, { recursive: true, force: true }); }
  }
});

function coreFixture() {
  const root = mkdtempSync(join(tmpdir(), 'native-core-binding-'));
  const f = fixture();
  const account = { account: { id: f.bindings.accounts[0].core_account.id, host: 'worker-one', provider: 'codex', identity_verified: true, email: 'private-display@example.invalid' }, classification: { status: 'assigned', group: 'personal', explicit: true } };
  const hosts = [{ environment: { spec: { name: 'worker-one' }, lifecycle: 'active' } }];
  const command = join(root, 'core'); const calls = join(root, 'calls.jsonl');
  writeFileSync(join(root, 'account.json'), JSON.stringify(account));
  writeFileSync(join(root, 'hosts.json'), JSON.stringify(hosts));
  writeFileSync(command, `#!${process.execPath}\nimport {appendFileSync,readFileSync} from 'node:fs';\nappendFileSync(${JSON.stringify(calls)},JSON.stringify(process.argv.slice(2))+'\\n');\nconst file=process.argv[3]==='account'?'account.json':'hosts.json';\nconsole.log(readFileSync(${JSON.stringify(root)}+'/'+file,'utf8'));\n`, { mode: 0o700 });
  return { ...f, root, account, hosts, core: { command, ledger: join(root, 'operator') }, calls };
}

test('Core resolution checks current registry and returns only launch references', () => {
  const f = coreFixture();
  try {
    const result = resolveCoreSelection(validateManifest(f.manifest), validateBindings(f.bindings), f.options, f.core);
    expect(result.dispatch).toEqual({ host: 'worker-one', account: f.account.account.id, group: 'personal', provider: 'codex', runtime: 'codex', runtime_version: '0.163.0', profile: 'coding', config_home: f.bindings.accounts[0].config_home });
    expect(result.runtime_args).toEqual(['exec', '--json', '--model', 'test-model']);
    expect(result.registry_checked).toBe(true);
    expect(result.credentials_checked).toBe(false);
    expect(JSON.stringify(result)).not.toContain('private-display');
    expect(readFileSync(f.calls, 'utf8').trim().split('\n').map(line => JSON.parse(line)[1])).toEqual(['account', 'environment']);
    f.account.classification.group = 'work'; writeFileSync(join(f.root, 'account.json'), JSON.stringify(f.account));
    expect(() => resolveCoreSelection(validateManifest(f.manifest), validateBindings(f.bindings), f.options, f.core)).toThrow('verified');
  } finally { rmSync(f.root, { recursive: true, force: true }); }
});

test('Core resolution refuses changed identity, host, provider, quarantine and retired hosts', () => {
  const mutations = [
    (f: any) => { f.account.account.id = `sha256:${'b'.repeat(64)}`; },
    (f: any) => { f.account.account.host = 'worker-two'; },
    (f: any) => { f.account.account.provider = 'claude'; },
    (f: any) => { f.account.account.identity_verified = false; },
    (f: any) => { f.account.classification.status = 'quarantine'; },
    (f: any) => { f.hosts[0].environment.lifecycle = 'retired'; },
    (f: any) => { f.hosts.length = 0; },
  ];
  for (const mutate of mutations) {
    const f = coreFixture();
    try {
      mutate(f);
      writeFileSync(join(f.root, 'account.json'), JSON.stringify(f.account));
      writeFileSync(join(f.root, 'hosts.json'), JSON.stringify(f.hosts));
      expect(() => resolveCoreSelection(validateManifest(f.manifest), validateBindings(f.bindings), f.options, f.core)).toThrow();
    } finally { rmSync(f.root, { recursive: true, force: true }); }
  }
});

test('native profile CLI resolves through Core without creating launch state', () => {
  const f = coreFixture();
  try {
    const manifest = join(f.root, 'manifest.json'); const bindings = join(f.root, 'bindings.json');
    writeFileSync(manifest, JSON.stringify(f.manifest)); writeFileSync(bindings, JSON.stringify(f.bindings));
    const args = ['--manifest', manifest, '--bindings', bindings, '--group', 'personal', '--profile', 'coding'];
    const command = resolve('agents/scripts/harness-profile.ts');
    const result = Bun.spawnSync([process.execPath, command, 'resolve-core', ...args, '--core', f.core.command, '--operator-ledger', f.core.ledger]);
    expect(result.exitCode).toBe(0);
    expect(JSON.parse(result.stdout.toString()).execution).toBe('not_started');
    expect(readdirSync(f.root)).not.toContain('state');
    const invalid = Bun.spawnSync([process.execPath, command, 'doctor', ...args, '--core', f.core.command]);
    expect(invalid.exitCode).toBe(2);
  } finally { rmSync(f.root, { recursive: true, force: true }); }
});

test('native manifests and bindings reject mixed transports and credential payloads', () => {
  const manifestMutations = [
    (m: any) => { m.connections[0].config_home = '/host/private'; },
    (m: any) => { m.connections[0].base_url = 'http://127.0.0.1:1234'; },
    (m: any) => { m.connections[0].token = 'secret'; },
  ];
  for (const mutate of manifestMutations) {
    const f = fixture(); mutate(f.manifest);
    expect(() => validateManifest(f.manifest)).toThrow();
  }
  const bindingMutations = [
    (b: any) => { b.accounts[0].base_url = 'http://127.0.0.1:1234'; },
    (b: any) => { b.accounts[0].config_home = 'relative/home'; },
    (b: any) => { b.accounts[0].config_home = '/home/with\nnewline'; },
    (b: any) => { b.accounts[0].token = 'secret'; },
    (b: any) => { b.accounts[0].core_account.id = 'unverified-label'; },
    (b: any) => { b.accounts[0].core_account.host = 'ssh://somewhere'; },
  ];
  for (const mutate of bindingMutations) {
    const f = fixture(); mutate(f.bindings);
    expect(() => validateBindings(f.bindings)).toThrow();
  }
});

test('native startup refuses missing homes, version drift and explicit asset injection before tasks', async () => {
  const root = mkdtempSync(join(tmpdir(), 'native-profile-refusal-'));
  try {
    const f = fixture();
    const home = join(root, 'existing-home');
    const command = join(root, 'native');
    const marker = join(root, 'task-started');
    f.bindings.accounts[0].config_home = home;
    f.bindings.commands.codex = command;
    writeFileSync(command, `#!${process.execPath}\nimport {writeFileSync} from 'node:fs';\nif(process.argv[2]==='--version')console.log('0.0.1');else writeFileSync(${JSON.stringify(marker)},'started');\n`, { mode: 0o700 });
    const selection = resolveProfile(validateManifest(f.manifest), validateBindings(f.bindings), f.options);
    const options = { cwd: root, state: join(root, 'state'), task: 'fixture task' };
    await expect(launch(selection, options)).rejects.toThrow();
    mkdirSync(home);
    await expect(launch(selection, options)).rejects.toThrow('does not match');
    await expect(launch(selection, { ...options, assets: { instructionsFile: '/untrusted/instructions' } })).rejects.toThrow('existing config home');
    expect(readdirSync(root)).not.toContain('task-started');
    expect(readdirSync(home)).toEqual([]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test('Core read failures and malformed responses fail closed without leaking output', () => {
  for (const mode of ['failed', 'malformed']) {
    const f = coreFixture();
    try {
      writeFileSync(f.core.command, `#!${process.execPath}\nconsole.log('private-output-sentinel');console.error('private-error-sentinel');process.exit(${mode === 'failed' ? 1 : 0});\n`, { mode: 0o700 });
      expect(() => resolveCoreSelection(validateManifest(f.manifest), validateBindings(f.bindings), f.options, f.core)).toThrow(mode === 'failed' ? 'Cannot confirm' : 'Invalid Core');
    } finally { rmSync(f.root, { recursive: true, force: true }); }
  }
});
