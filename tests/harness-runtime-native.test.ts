import { expect, test } from 'bun:test';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { launch } from '../agents/scripts/harness-runtime';
import { resolveConnection, validateCatalog } from '../agents/scripts/model-connection';

// Explicitly opt in with the pinned Nix binary. This never contacts a provider:
// every model response and tool request comes from an in-process loopback server.
const binary = process.env.HARNESS_TEST_DSH_BINARY;
const pin = '0.2.1-rc.2';
function response(content: unknown[], stopReason: string) {
  const events: [string, unknown][] = [['message_start', { type: 'message_start', message: { id: 'msg_fixture', type: 'message', role: 'assistant', model: 'synthetic-model', content: [], stop_reason: null, stop_sequence: null, usage: { input_tokens: 10, output_tokens: 0 } } }]];
  for (const [index, block] of content.entries()) {
    const value = block as any;
    events.push(['content_block_start', { type: 'content_block_start', index, content_block: value.type === 'tool_use' ? { ...value, input: {} } : { type: 'text', text: '' } }]);
    events.push(['content_block_delta', { type: 'content_block_delta', index, delta: value.type === 'tool_use' ? { type: 'input_json_delta', partial_json: JSON.stringify(value.input) } : { type: 'text_delta', text: value.text } }]);
    events.push(['content_block_stop', { type: 'content_block_stop', index }]);
  }
  events.push(['message_delta', { type: 'message_delta', delta: { stop_reason: stopReason, stop_sequence: null }, usage: { output_tokens: 10 } }]);
  events.push(['message_stop', { type: 'message_stop' }]);
  return new Response(events.map(([event, data]) => `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`).join(''), { headers: { 'Content-Type': 'text/event-stream' } });
}

test.skipIf(!binary)('pinned dsh loads private config, shared assets, and completes a synthetic model/tool round trip', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-native-roundtrip-'));
  const requests: any[] = [];
  const skills = join(root, 'shared-skills'); const instructions = join(root, 'shared.md');
  await mkdir(join(root, '.git')); await mkdir(join(skills, 'synthetic-skill'), { recursive: true });
  await writeFile(join(root, 'fixture.txt'), 'SYNTHETIC_FIXTURE');
  await writeFile(instructions, 'fixture-shared-instructions');
  await writeFile(join(skills, 'synthetic-skill', 'SKILL.md'), '---\nname: synthetic-skill\ndescription: Synthetic local test skill\n---\nSynthetic skill body\n');
  const server = Bun.serve({ hostname: '127.0.0.1', port: 0, async fetch(request) {
    const body = await request.json(); requests.push(body);
    const tool = body.tools?.find((t: any) => t.name === 'read');
    if (requests.length === 1 && tool) return response([{ type: 'tool_use', id: 'tool_fixture', name: tool.name, input: { file_path: join(root, 'fixture.txt') } }], 'tool_use');
    return response([{ type: 'text', text: 'Synthetic fixture checked' }], 'end_turn');
  } });
  try {
    const catalog = validateCatalog({ schema_version: 1, default_runtime: 'dsh', runtimes: { dsh: { command: binary, version: pin } },
      connections: [{ id: 'synthetic', group: 'testing', provider: 'synthetic', account_ref: 'synthetic', billing: 'api', transport: 'anthropic-messages', base_url: server.url.origin,
        models: { main: { id: 'synthetic-model', context_window: 32000, max_output_tokens: 1024 } } }],
      profiles: [{ id: 'synthetic', connection: 'synthetic' }],
    });
    const result = await launch(resolveConnection(catalog, { profile: 'synthetic', group: 'testing' }), { cwd: root, state: join(root, 'state'), task: 'Read fixture.txt and report its content', timeoutMs: 20_000, assets: { instructionsFile: instructions, skillsDirectory: skills } });
    expect(result.code).toBe(0);
    expect(requests).toHaveLength(2);
    expect(JSON.stringify(requests[0])).toContain('fixture-shared-instructions');
    expect(JSON.stringify(requests[0])).toContain('synthetic-skill');
    expect(JSON.stringify(requests[1])).toContain('SYNTHETIC_FIXTURE');
    expect(JSON.parse(await readFile(join(result.directory, 'outcome.json'), 'utf8')).task_success).toBe('unverified');
  } finally { server.stop(true); await rm(root, { recursive: true, force: true }); }
}, 30_000);

test.skipIf(!binary)('pinned dsh cancels a pending synthetic inference at the launcher deadline', async () => {
  const root = await mkdtemp(join(tmpdir(), 'dsh-native-cancel-'));
  let requests = 0;
  const server = Bun.serve({ hostname: '127.0.0.1', port: 0, fetch() { requests++; return new Promise<Response>(() => {}); } });
  try {
    const catalog = validateCatalog({ schema_version: 1, default_runtime: 'dsh', runtimes: { dsh: { command: binary, version: pin } },
      connections: [{ id: 'synthetic', group: 'testing', provider: 'synthetic', account_ref: 'synthetic', billing: 'api', transport: 'anthropic-messages', base_url: server.url.origin,
        models: { main: { id: 'synthetic-model', context_window: 32000, max_output_tokens: 1024 } } }], profiles: [{ id: 'synthetic', connection: 'synthetic' }],
    });
    const result = await launch(resolveConnection(catalog, { profile: 'synthetic', group: 'testing' }), { cwd: root, state: join(root, 'state'), task: 'Wait for a response', timeoutMs: 4000 });
    expect(result.code).toBe(3); expect(requests).toBe(1);
  } finally { server.stop(true); await rm(root, { recursive: true, force: true }); }
}, 15_000);

test.skipIf(!binary)('pinned dsh improvement adapter writes a structured response through its real write tool', async () => {
  const { createHash } = await import('node:crypto');
  const { runStage } = await import('../agents/scripts/harness-improvement-runtime');
  const { validateManifest } = await import('../agents/scripts/harness-profile');
  const root = await mkdtemp(join(tmpdir(), 'dsh-improvement-native-'));
  const requests: any[] = [];
  const server = Bun.serve({ hostname: '127.0.0.1', port: 0, async fetch(request) {
    const body = await request.json(); requests.push(body);
    const write = body.tools?.find((tool: any) => tool.name === 'write');
    if (requests.length === 1 && write) return response([{ type: 'tool_use', id: 'write_fixture', name: write.name,
      input: { file_path: join(root, 'native-response.json'), content: '{"answer":85}' } }], 'tool_use');
    return response([{ type: 'text', text: 'Structured fixture saved' }], 'end_turn');
  } });
  try {
    const manifest = validateManifest({ schema_version: 1, default_runtime: 'dsh', runtimes: { dsh: { version: pin } },
      connections: [{ id: 'synthetic', group: 'testing', provider: 'synthetic', account_ref: 'synthetic', billing: 'api', transport: 'anthropic-messages',
        models: { main: { id: 'synthetic-model', context_window: 32000, max_output_tokens: 1024 } } }], profiles: [{ id: 'synthetic', connection: 'synthetic' }] });
    const manifestPath = join(root, 'manifest.json'); const bindingsPath = join(root, 'bindings.json');
    await writeFile(manifestPath, JSON.stringify(manifest));
    await writeFile(bindingsPath, JSON.stringify({ schema_version: 1, commands: { dsh: binary },
      accounts: [{ connection: 'synthetic', group: 'testing', account_ref: 'synthetic', base_url: server.url.origin }] }));
    const file_pins = Object.fromEntries(await Promise.all([binary!, manifestPath, bindingsPath].map(async path => [path, `sha256:${createHash('sha256').update(await readFile(path)).digest('hex')}`])));
    const result = await runStage({ schema_version: 1, stage: 'solve', runtime: 'dsh', runtime_version: pin,
      account: 'synthetic', group: 'testing', timeout_ms: 25_000, file_pins, editable_paths: ['AGENTS.md'],
      input: { task: 'Sum signed ledger amounts', assets: { 'AGENTS.md': 'include-debits' } } },
    { kind: 'gateway', runtime: 'dsh', manifest: manifestPath, bindings: bindingsPath, profile: 'synthetic', group: 'testing' }, root);
    expect(result).toEqual({ answer: 85 });
    expect(requests).toHaveLength(2);
    expect(JSON.stringify(requests[0])).toContain('include-debits');
  } finally { server.stop(true); await rm(root, { recursive: true, force: true }); }
});
