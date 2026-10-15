import { expect, test } from 'bun:test';
import { argumentsFor, resolveConnection, validateCatalog } from '../agents/scripts/model-connection';
import example from '../agents/model-connections/example.json';
const select = (c: unknown = example, runtime?: string) => resolveConnection(validateCatalog(c), { profile: 'development', group: 'personal', runtime });

test('runtime and connection are independently selectable without changing defaults', () => {
  const a = select(); const b = select(example, 'claude-code');
  expect(a.runtime).toBe('dsh');
  expect(b.connection).toEqual(a.connection);
  expect(a.fingerprint).not.toBe(b.fingerprint);
  expect(select()).toEqual(a);
  expect(a.automatic_fallback).toBe(false);
  expect(a.on_limit).toBe('stop');
});
test('unknown groups, runtimes and profiles fail closed', () => {
  const c = validateCatalog(example);
  for (const options of [
    { profile: 'development', group: 'work' },
    { profile: 'missing', group: 'personal' },
    { profile: 'development', group: 'personal', runtime: 'unknown' },
  ]) expect(() => resolveConnection(c, options)).toThrow();
});
test('endpoint changes, model changes and engine updates change the binding', () => {
  const baseline = select().fingerprint;
  for (const mutate of [
    (c: typeof example) => { c.connections[0].base_url = 'http://127.0.0.1:18766'; },
    (c: typeof example) => { c.connections[0].models.main.id = 'another-model'; },
    (c: typeof example) => { c.runtimes.dsh.version = '0.2.1-alpha.4'; },
    (c: typeof example) => { c.connections[0].account_ref = 'other'; },
  ]) { const c = structuredClone(example); mutate(c); expect(select(c).fingerprint).not.toBe(baseline); }
});
test('reject network listeners, URL secrets and ambiguous upstream ownership', () => {
  for (const base_url of ['https://example.com', 'http://localhost:18765', 'http://127.0.0.1:18765/v1', 'http://secret@127.0.0.1', 'http://127.0.0.1?key=secret']) {
    const c = structuredClone(example); c.connections[0].base_url = base_url;
    expect(() => select(c)).toThrow();
  }
  const c = structuredClone(example);
  c.connections.push({ ...c.connections[0], id: 'work', group: 'work' });
  expect(() => select(c)).toThrow('different account scopes');
});
test('reject duplicate IDs, bad references, secrets, implicit pooling and invalid capacities', () => {
  const mutations = [
    (c: any) => c.connections.push(c.connections[0]),
    (c: any) => c.profiles.push(c.profiles[0]),
    (c: any) => { c.profiles[0].connection = 'missing'; },
    (c: any) => { c.connections[0].api_key = 'secret'; },
    (c: any) => { c.connections[0].pool = true; },
    (c: any) => { c.connections[0].models.main.context_window = -1; },
    (c: any) => { c.connections[0].models.main.max_output_tokens = 1000000; },
    (c: any) => { c.runtimes.dsh.version = 'latest'; },
    (c: any) => { c.runtimes.dsh.command = 'sh -c unsafe'; },
  ];
  for (const mutate of mutations) { const c = structuredClone(example); mutate(c); expect(() => select(c)).toThrow(); }
});
test('resolved selections do not retain mutable catalog objects', () => {
  const c = validateCatalog(example); const selection = select(c);
  c.connections[0].account_ref = 'other';
  expect(selection.connection.account_ref).toBe('personal-chatgpt');
});
test('CLI flags reject unknown, missing and repeated values', () => {
  for (const args of [['--config'], ['--config', 'a', '--config', 'b'], ['--unsafe', 'yes'], ['config', 'a']]) {
    expect(() => argumentsFor(args, ['config'])).toThrow();
  }
});
