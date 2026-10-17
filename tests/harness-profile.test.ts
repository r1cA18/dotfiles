import { expect, test } from 'bun:test';
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { doctorProfiles, resolveProfile, validateBindings, validateManifest, type DeviceBindings } from '../agents/scripts/harness-profile';
import { renderRuntime } from '../agents/scripts/harness-runtime';
import example from '../agents/model-connections/example.json';
function fixture() {
  const manifest = validateManifest({ ...example,
    runtimes: { dsh: { version: '0.2.1-rc.2' }, 'claude-code': { version: example.runtimes['claude-code'].version }, codex: { version: '1.2.3' } },
    connections: example.connections.map(({ base_url, ...c }) => ({ ...c, billing: 'api' })),
  });
  const bindings: DeviceBindings = { schema_version: 1, commands: { dsh: 'dsh', 'claude-code': 'claude', codex: 'codex' }, accounts: [{ connection: 'personal-chatgpt', group: 'personal', account_ref: 'personal-chatgpt', base_url: 'http://127.0.0.1:18765' }] };
  return { manifest, bindings, options: { profile: 'development', group: 'personal' } };
}

test('portable profile uses device commands and gateways without changing its identity', () => {
  const f = fixture(); const first = resolveProfile(f.manifest, f.bindings, f.options);
  const original = structuredClone(f.manifest);
  const portable = doctorProfiles(f.manifest, f.bindings, f.options)[0].manifest_fingerprint;
  f.bindings.commands.dsh = '/other-device/bin/dsh'; f.bindings.accounts[0].base_url = 'http://127.0.0.1:18766';
  const second = resolveProfile(f.manifest, f.bindings, f.options);
  expect(second.engine.command).toBe('/other-device/bin/dsh');
  expect(second.connection.base_url).toBe('http://127.0.0.1:18766');
  expect(second.fingerprint).not.toBe(first.fingerprint);
  expect(doctorProfiles(f.manifest, f.bindings, f.options)[0].manifest_fingerprint).toBe(portable);
  expect(f.manifest).toEqual(original);
});
test('new devices receive actionable missing binding reports without native state inspection', () => {
  const f = fixture(); f.bindings.commands = {}; f.bindings.accounts = [];
  const result = doctorProfiles(f.manifest, f.bindings, f.options)[0];
  expect(result.status).toBe('blocked');
  expect(result.issues.map(i => i.code)).toEqual(['runtime_binding_missing', 'account_binding_missing']);
  expect(result.credentials_checked).toBe(false); expect(result.inference_checked).toBe(false);
  expect(() => resolveProfile(f.manifest, f.bindings, f.options)).toThrow('binding_missing');
});
test('account and group mismatches block resolution even with a reachable-looking gateway', () => {
  for (const field of ['group', 'account_ref'] as const) {
    const f = fixture(); f.bindings.accounts[0][field] = 'another';
    expect(doctorProfiles(f.manifest, f.bindings, f.options)[0].issues[0].code).toBe('account_binding_mismatch');
    expect(() => resolveProfile(f.manifest, f.bindings, f.options)).toThrow();
  }
  const f = fixture(); expect(() => resolveProfile(f.manifest, f.bindings, { ...f.options, group: 'work' })).toThrow();
});
test('a gateway cannot bind different account scopes across portable profiles', () => {
  const f = fixture(); f.manifest.connections.push({ ...f.manifest.connections[0], id: 'other', group: 'work', account_ref: 'work' });
  f.bindings.accounts.push({ ...f.bindings.accounts[0], connection: 'other', group: 'work', account_ref: 'work' });
  expect(() => resolveProfile(f.manifest, f.bindings, f.options)).toThrow('gateway_scope_conflict');
});
test('subscription gateways fail closed without importing native OAuth or choosing a fallback', () => {
  for (const provider of ['openai', 'anthropic']) {
    const f = fixture(); f.manifest.connections[0].billing = 'subscription'; f.manifest.connections[0].provider = provider;
    expect(doctorProfiles(f.manifest, f.bindings, f.options)[0].status).toBe('blocked');
    expect(() => resolveProfile(f.manifest, f.bindings, f.options)).toThrow(provider === 'anthropic' ? 'unsupported' : 'unimplemented');
  }
});
test('Codex is a peer runtime declaration but unsupported gateway transport cannot launch', () => {
  const f = fixture(); const options = { ...f.options, runtime: 'codex' };
  expect(doctorProfiles(f.manifest, f.bindings, options)[0].issues.map(i => i.code)).toEqual(['transport_unsupported']);
  expect(() => resolveProfile(f.manifest, f.bindings, options)).toThrow('transport_unsupported');
  const selection = resolveProfile(f.manifest, f.bindings, f.options);
  expect(() => renderRuntime({ ...selection, runtime: 'codex' })).toThrow('does not support');
});
test('portable manifests reject host locations, secret fields, pools, and floating pins', () => {
  const mutations = [
    (m: any) => { m.connections[0].base_url = 'http://127.0.0.1:1234'; },
    (m: any) => { m.runtimes.dsh.command = '/private/device/dsh'; },
    (m: any) => { m.connections[0].api_key = 'secret'; },
    (m: any) => { m.connections[0].pool = true; },
    (m: any) => { m.runtimes.dsh.version = 'latest'; },
  ];
  for (const mutate of mutations) { const f = fixture(); mutate(f.manifest); expect(() => validateManifest(f.manifest)).toThrow(); }
});
test('device bindings reject command injection, remote URLs, duplicates, and native credential state', () => {
  const mutations = [
    (b: any) => { b.commands.dsh = 'sh -c arbitrary'; },
    (b: any) => { b.accounts[0].base_url = 'http://secret@127.0.0.1'; },
    (b: any) => { b.accounts[0].base_url = 'https://example.com'; },
    (b: any) => { b.accounts[0].base_url = 'http://127.0.0.1:18765 '; },
    (b: any) => { b.accounts[0].base_url = 'http://127.0.0.1:18\t765'; },
    (b: any) => { b.accounts[0].token = 'secret'; },
    (b: any) => { b.accounts.push(b.accounts[0]); },
    (b: any) => { b.native_home = '/existing/credentials'; },
  ];
  for (const mutate of mutations) { const f = fixture(); mutate(f.bindings); expect(() => validateBindings(f.bindings)).toThrow(); }
});
test('doctor CLI writes no files and distinguishes blocked configuration from invalid input', () => {
  const root = mkdtempSync(join(tmpdir(), 'profile-doctor-'));
  try {
    const f = fixture(); f.bindings.accounts = [];
    const manifest = join(root, 'manifest.json'); const device = join(root, 'device.json');
    writeFileSync(manifest, JSON.stringify(f.manifest)); writeFileSync(device, JSON.stringify(f.bindings));
    const args = ['--manifest', manifest, '--bindings', device, '--group', 'personal'];
    const before = readdirSync(root);
    const result = Bun.spawnSync([process.execPath, resolve('agents/scripts/harness-profile.ts'), 'doctor', ...args]);
    expect(result.exitCode).toBe(1); expect(JSON.parse(result.stdout.toString())[0].issues[0].code).toBe('account_binding_missing');
    const plan = Bun.spawnSync([process.execPath, resolve('agents/scripts/harness-runtime.ts'), 'plan', ...args, '--profile', 'development']);
    expect(plan.exitCode).toBe(2); expect(readdirSync(root)).toEqual(before);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
