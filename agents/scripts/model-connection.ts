import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

export type Runtime = 'dsh' | 'claude-code' | 'codex';
export const runtimeCommands: Record<Runtime, string> = { dsh: 'dsh', 'claude-code': 'claude', codex: 'codex' };
export interface Model { id: string; context_window: number; max_output_tokens: number }
interface ConnectionScope {
  id: string;
  group: string;
  provider: string;
  account_ref: string;
  billing: 'subscription' | 'api';
  models: { main: Model; small?: Model };
}
export interface GatewayConnection extends ConnectionScope {
  transport: 'anthropic-messages';
  base_url: string;
}
export interface NativeConnection extends ConnectionScope {
  transport: 'native';
  config_home: string;
  core_account?: CoreAccountReference;
}
export interface CoreAccountReference { host: string; id: string }
export type Connection = GatewayConnection | NativeConnection;
// Capability checks belong to the selected transport. A declaration does not
// authorize importing another application's subscription credentials.
export function gatewayIssue(connection: Pick<Connection, 'billing' | 'provider'>, runtime: string) {
  if (runtime === 'codex') return { code: 'transport_unsupported', message: 'Codex does not support Anthropic Messages gateway transport; explicitly select native Codex separately' };
  if (connection.billing === 'subscription') return connection.provider === 'anthropic'
    ? { code: 'subscription_route_unsupported', message: 'Claude subscription credentials are reserved for native Anthropic applications; explicitly select unmodified Claude Code separately' }
    : connection.provider === 'openai'
      ? { code: 'subscription_adapter_unimplemented', message: 'ChatGPT plan usage requires app-specific official sign-in and a compatible Responses adapter; native Codex credentials are not imported' }
      : { code: 'subscription_route_unsupported', message: 'This provider has no supported subscription gateway adapter' };
  return undefined;
}
export function connectionIssue(connection: Pick<Connection, 'billing' | 'provider' | 'transport'>, runtime: string) {
  if (connection.transport !== 'native') return gatewayIssue(connection, runtime);
  if (runtime === 'codex' && connection.provider === 'openai' || runtime === 'claude-code' && connection.provider === 'anthropic') return undefined;
  return { code: 'native_route_unsupported', message: 'Select the native runtime matching this provider; native credentials are not shared with another runtime' };
}
export interface Catalog {
  schema_version: 1;
  default_runtime: Runtime;
  runtimes: Partial<Record<Runtime, { command: string; version: string }>>;
  connections: Connection[];
  profiles: { id: string; connection: string; runtime?: Runtime }[];
}
const runtimes = Object.keys(runtimeCommands) as Runtime[];
const identifier = /^[a-z][a-z0-9-]{0,63}$/;
const plain = (x: unknown): x is Record<string, unknown> => !!x && typeof x === 'object' && !Array.isArray(x);
function object(value: unknown, keys: string[], required = keys): Record<string, unknown> {
  if (!plain(value) || Object.keys(value).some(k => !keys.includes(k)) || required.some(k => !Object.hasOwn(value, k))) {
    throw new Error('Invalid configuration fields');
  }
  return value;
}
function text(value: unknown): string {
  if (typeof value !== 'string' || !value.length || /[\s\x00-\x1f\x7f]/u.test(value)) throw new Error('Invalid string');
  return value;
}
function id(value: unknown): string {
  const result = text(value);
  if (!identifier.test(result)) throw new Error('Invalid identifier');
  return result;
}
export function validateConfigHome(value: unknown): string {
  if (typeof value !== 'string' || !value.startsWith('/') || value.length > 1024 || /[\x00-\x1f\x7f]/u.test(value)
    || value.includes('://') || value.includes('=') || value.toLowerCase().split(/[/ ._-]/u).some(part => part.length >= 32)
    || value.toLowerCase().split('/').some(part => /^(sk-|ghp_|gho_|github_pat_|xox|akia|eyj)/u.test(part))) throw new Error('Use an absolute config-home reference without credential values');
  return value;
}
export function validateCoreAccount(value: unknown): CoreAccountReference {
  const reference = object(value, ['host', 'id']);
  id(reference.host);
  if (typeof reference.id !== 'string' || !/^sha256:[a-f0-9]{64}$/.test(reference.id)) throw new Error('Use the host-scoped Core account ID');
  return reference as unknown as CoreAccountReference;
}
function model(value: unknown): Model {
  const m = object(value, ['id', 'context_window', 'max_output_tokens']);
  text(m.id);
  for (const key of ['context_window', 'max_output_tokens']) {
    if (!Number.isSafeInteger(m[key]) || (m[key] as number) < 1) throw new Error('Invalid model capacity');
  }
  if ((m.max_output_tokens as number) > (m.context_window as number)) throw new Error('Output exceeds context window');
  return m as unknown as Model;
}

export function validateCatalog(input: unknown): Catalog {
  const c = object(input, ['schema_version', 'default_runtime', 'runtimes', 'connections', 'profiles']);
  if (c.schema_version !== 1 || !runtimes.includes(String(c.default_runtime))) throw new Error('Unsupported catalog');
  const engines = object(c.runtimes, runtimes, []);
  if (!Object.hasOwn(engines, String(c.default_runtime))) throw new Error('Default runtime is not configured');
  for (const runtime of Object.keys(engines) as Runtime[]) {
    const engine = object(engines[runtime], ['command', 'version']);
    const command = text(engine.command);
    if (!(command === runtimeCommands[runtime] || command.startsWith('/'))) throw new Error('Use a native command or absolute executable path');
    if (!/^\d+\.\d+\.\d+(?:-[a-zA-Z0-9.-]+)?$/.test(text(engine.version))) throw new Error('Pin an exact runtime version');
  }
  if (!Array.isArray(c.connections) || !c.connections.length || !Array.isArray(c.profiles) || !c.profiles.length) throw new Error('Empty catalog');
  const connections = new Map<string, Connection>();
  const endpoints = new Map<string, string>();
  for (const value of c.connections) {
    const native = plain(value) && value.transport === 'native';
    const fields = ['id', 'group', 'provider', 'account_ref', 'billing', 'transport', native ? 'config_home' : 'base_url', 'models'];
    const v = object(value, native ? [...fields, 'core_account'] : fields, fields);
    const key = id(v.id);
    if (connections.has(key)) throw new Error('Duplicate connection');
    id(v.group); id(v.provider); id(v.account_ref);
    if (!['subscription', 'api'].includes(String(v.billing)) || !['anthropic-messages', 'native'].includes(String(v.transport))) throw new Error('Unsupported connection');
    const owner = `${v.group}:${v.account_ref}:${v.provider}:${v.billing}`;
    if (native) {
      const home = resolve(validateConfigHome(v.config_home));
      if (v.core_account !== undefined) validateCoreAccount(v.core_account);
      if (endpoints.has(home) && endpoints.get(home) !== owner) throw new Error('A native config home cannot represent different account scopes');
      endpoints.set(home, owner);
    }
    else {
      const url = new URL(text(v.base_url));
      if (url.protocol !== 'http:' || !['127.0.0.1', '[::1]'].includes(url.hostname) || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Use an unauthenticated loopback gateway origin');
      if (endpoints.has(url.origin) && endpoints.get(url.origin) !== owner) throw new Error('A gateway cannot represent different account scopes');
      endpoints.set(url.origin, owner);
    }
    const models = object(v.models, native ? ['main'] : ['main', 'small'], ['main']);
    model(models.main);
    if (Object.hasOwn(models, 'small')) model(models.small);
    connections.set(key, v as unknown as Connection);
  }
  const profiles = new Set<string>();
  for (const value of c.profiles) {
    const p = object(value, ['id', 'connection', 'runtime'], ['id', 'connection']);
    const key = id(p.id);
    if (profiles.has(key) || !connections.has(id(p.connection)) || (p.runtime !== undefined && !Object.hasOwn(engines, String(p.runtime)))) throw new Error('Invalid profile reference');
    profiles.add(key);
  }
  // Own the parsed data: later caller mutations must not alter a resolved plan.
  return structuredClone(c) as unknown as Catalog;
}

export async function loadCatalog(path: string): Promise<Catalog> {
  return validateCatalog(JSON.parse(await readFile(path, 'utf8')));
}

export function resolveConnection(catalog: Catalog, options: { profile: string; group: string; runtime?: string }) {
  const c = validateCatalog(catalog);
  const profile = c.profiles.find(p => p.id === options.profile);
  if (!profile) throw new Error('Unknown profile');
  const connection = c.connections.find(item => item.id === profile.connection)!;
  if (connection.group !== options.group) throw new Error('Profile is outside the requested account group');
  const runtime = options.runtime ?? profile.runtime ?? c.default_runtime;
  if (!runtimes.includes(runtime as Runtime) || !c.runtimes[runtime as Runtime]) throw new Error('Unsupported runtime');
  const selection = {
    schema_version: 1 as const, profile: profile.id, runtime: runtime as Runtime,
    engine: c.runtimes[runtime as Runtime]!, connection,
    on_limit: 'stop' as const, automatic_fallback: false as const,
  };
  const fingerprint = createHash('sha256').update(JSON.stringify(selection)).digest('hex');
  return { ...selection, fingerprint: `sha256:${fingerprint}` };
}
export type Selection = ReturnType<typeof resolveConnection>;

export function nativeArguments(connection: NativeConnection, runtime: Runtime): string[] {
  const issue = connectionIssue(connection, runtime);
  if (issue) throw new Error(`${issue.code}: ${issue.message}`);
  return runtime === 'codex' ? ['exec', '--json', '--model', connection.models.main.id] : ['--print', '--model', connection.models.main.id];
}

export function argumentsFor(args: string[], allowed: string[]) {
  const result: Record<string, string> = {};
  while (args.length) {
    const key = args.shift()!;
    const value = args.shift();
    if (!key.startsWith('--') || !allowed.includes(key.slice(2)) || Object.hasOwn(result, key.slice(2)) || value === undefined || value.startsWith('--')) throw new Error('Invalid or repeated argument');
    result[key.slice(2)] = value;
  }
  return result;
}

if (import.meta.main) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const flags = argumentsFor(args, ['config', 'profile', 'group', 'runtime']);
    if (!flags.config) throw new Error('Explicit --config is required');
    const catalog = await loadCatalog(flags.config);
    if (command === 'list' && !flags.profile && !flags.runtime && flags.group) {
      console.log(JSON.stringify(catalog.profiles.filter(p => catalog.connections.find(c => c.id === p.connection)?.group === flags.group), null, 2));
    } else if (command === 'resolve' && flags.profile && flags.group) {
      console.log(JSON.stringify(resolveConnection(catalog, { profile: flags.profile, group: flags.group, runtime: flags.runtime }), null, 2));
    } else throw new Error('Usage: model-connection.ts list|resolve --config <file> --group <group> [--profile <id>] [--runtime dsh|claude-code|codex]');
  } catch (error) {
    console.error((error as Error).message);
    process.exitCode = 2;
  }
}
