import { expect, test } from 'bun:test';

test('jq launcher identity retains same-email accounts and punctuation collisions', () => {
  const data = { result: { codex: { accounts: [
    { id: 'personal-1', email: 'same@example.com' },
    { id: 'company-2', email: 'same@example.com' },
    { id: 'other-3', email: 'a+b@example.com' },
    { id: 'other-4', email: 'a-b@example.com' },
  ] } } };
  const result = Bun.spawnSync(['jq', '-rf', new URL('./orca-account-launchers.jq', import.meta.url).pathname], { stdin: Buffer.from(JSON.stringify(data)) });
  expect(result.exitCode).toBe(0);
  const rows = result.stdout.toString().trim().split('\n');
  expect(rows).toHaveLength(4);
  expect(new Set(rows.map((r) => r.split('\t')[3])).size).toBe(4);
});

test('jq rejects account IDs that could escape a managed path', () => {
  const data = { result: { codex: { accounts: [{ id: '../outside', email: 'same@example.com' }] } } };
  const result = Bun.spawnSync(['jq', '-rf', new URL('./orca-account-launchers.jq', import.meta.url).pathname], { stdin: Buffer.from(JSON.stringify(data)) });
  expect(result.exitCode).not.toBe(0);
});
