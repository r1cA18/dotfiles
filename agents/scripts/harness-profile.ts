import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { argumentsFor, connectionIssue, runtimeCommands, nativeArguments, validateCatalog, validateConfigHome, validateCoreAccount, resolveConnection, type Catalog, type GatewayConnection, type NativeConnection, type CoreAccountReference, type Runtime } from './model-connection';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

// Portable intent stays in Git. Executable locations and credential references stay
// on the device. Neither document contains credentials or native account state.
export interface ProfileManifest extends Omit<Catalog, 'runtimes' | 'connections'> {
  runtimes: Partial<Record<Runtime, { version: string }>>;
  connections: (Omit<GatewayConnection, 'base_url'> | Omit<NativeConnection, 'config_home' | 'core_account'>)[];
}
interface DeviceAccountScope { connection: string; group: string; account_ref: string }
export type DeviceAccount = DeviceAccountScope & ({ base_url: string } | { config_home: string; core_account?: CoreAccountReference });
export interface DeviceBindings {
  schema_version: 1;
  commands: Partial<Record<Runtime, string>>;
  accounts: DeviceAccount[];
}
function object(value: unknown, keys: string[], required = keys): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value) || Object.keys(value).some(k => !keys.includes(k)) || required.some(k => !Object.hasOwn(value, k))) throw new Error('Invalid profile configuration fields');
  return value as Record<string, unknown>;
}
function identifier(value: unknown): string {
  if (typeof value !== 'string' || !/^[a-z][a-z0-9-]{0,63}$/.test(value)) throw new Error('Invalid profile identifier');
  return value;
}
const digest = (value: unknown) => `sha256:${createHash('sha256').update(JSON.stringify(value)).digest('hex')}`;

export function validateManifest(input: unknown): ProfileManifest {
  const m = object(input, ['schema_version', 'default_runtime', 'runtimes', 'connections', 'profiles']);
  const engines = object(m.runtimes, Object.keys(runtimeCommands), []);
  const runtimes: Catalog['runtimes'] = {};
  for (const [runtime, pin] of Object.entries(engines)) {
    const value = object(pin, ['version']);
    runtimes[runtime as Runtime] = { command: runtimeCommands[runtime as Runtime], version: value.version as string };
  }
  if (!Array.isArray(m.connections)) throw new Error('Invalid manifest connections');
  // Reuse the catalog contract with synthetic loopback origins only for pure
  // validation. No host-specific value or network request enters the manifest.
  const connections = m.connections.map((item, index) => {
    const connection = object(item, ['id', 'group', 'provider', 'account_ref', 'billing', 'transport', 'models']);
    return { ...connection, ...(connection.transport === 'native' ? { config_home: `/synthetic/home-${index}` } : { base_url: `http://127.0.0.1:${10000 + index}` }) };
  });
  validateCatalog({ ...m, runtimes, connections });
  return structuredClone(m) as unknown as ProfileManifest;
}

export function validateBindings(input: unknown): DeviceBindings {
  const b = object(input, ['schema_version', 'commands', 'accounts']);
  if (b.schema_version !== 1 || !Array.isArray(b.accounts)) throw new Error('Unsupported device bindings');
  const commands = object(b.commands, Object.keys(runtimeCommands), []);
  for (const [runtime, command] of Object.entries(commands)) {
    if (typeof command !== 'string' || /[\s\x00-\x1f\x7f]/u.test(command) || !(command === runtimeCommands[runtime as Runtime] || command.startsWith('/'))) throw new Error('Use a native command or absolute executable path');
  }
  const accounts = new Set<string>();
  for (const item of b.accounts) {
    const native = !!item && typeof item === 'object' && Object.hasOwn(item, 'config_home');
    const fields = ['connection', 'group', 'account_ref', native ? 'config_home' : 'base_url'];
    const a = object(item, native ? [...fields, 'core_account'] : fields, fields);
    const key = identifier(a.connection); identifier(a.group); identifier(a.account_ref);
    if (accounts.has(key)) throw new Error('Duplicate device account binding');
    accounts.add(key);
    if (native) {
      validateConfigHome(a.config_home);
      if (a.core_account !== undefined) validateCoreAccount(a.core_account);
    } else {
      if (typeof a.base_url !== 'string' || !a.base_url.length || /[\s\x00-\x1f\x7f]/u.test(a.base_url)) throw new Error('Invalid gateway origin');
      const url = new URL(a.base_url);
      if (url.protocol !== 'http:' || !['127.0.0.1', '[::1]'].includes(url.hostname) || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Use an unauthenticated loopback gateway origin');
    }
  }
  return structuredClone(b) as unknown as DeviceBindings;
}

function bind(manifest: ProfileManifest, bindings: DeviceBindings, options: { profile: string; runtime?: string }): Catalog {
  const profile = manifest.profiles.find(p => p.id === options.profile)!;
  const connection = manifest.connections.find(c => c.id === profile.connection)!;
  const runtime = (options.runtime ?? profile.runtime ?? manifest.default_runtime) as Runtime;
  const account = bindings.accounts.find(a => a.connection === connection.id)!;
  return validateCatalog({
    ...manifest,
    default_runtime: runtime,
    runtimes: { [runtime]: { ...manifest.runtimes[runtime], command: bindings.commands[runtime] } },
    profiles: [{ ...profile, runtime }],
    connections: [{ ...connection, ...('config_home' in account ? { config_home: account.config_home, ...(account.core_account ? { core_account: account.core_account } : {}) } : { base_url: account.base_url }) }],
  });
}

export function doctorProfiles(input: ProfileManifest, device: DeviceBindings, options: { group: string; profile?: string; runtime?: string }) {
  const manifest = validateManifest(input); const bindings = validateBindings(device);
  const profiles = manifest.profiles.filter(p => (!options.profile || p.id === options.profile) && manifest.connections.find(c => c.id === p.connection)?.group === options.group);
  if (!profiles.length) throw new Error('No profile in the requested account group');
  return profiles.map(profile => {
    const connection = manifest.connections.find(c => c.id === profile.connection)!;
    const runtime = options.runtime ?? profile.runtime ?? manifest.default_runtime;
    const issues: { code: string; message: string }[] = [];
    if (!Object.hasOwn(manifest.runtimes, runtime)) issues.push({ code: 'runtime_pin_missing', message: 'Add an exact version for the explicitly selected runtime' });
    if (!Object.hasOwn(bindings.commands, runtime)) issues.push({ code: 'runtime_binding_missing', message: 'Bind the runtime executable on this device' });
    const account = bindings.accounts.find(a => a.connection === connection.id);
    if (!account) issues.push({ code: 'account_binding_missing', message: 'Bind an account-specific gateway or native config home on this device' });
    else if (account.group !== connection.group || account.account_ref !== connection.account_ref) issues.push({ code: 'account_binding_mismatch', message: 'Device account reference or group differs from the portable profile' });
    else if ((connection.transport === 'native') !== ('config_home' in account)) issues.push({ code: 'transport_binding_mismatch', message: 'Device binding does not match the selected transport' });
    const capability = connectionIssue(connection, runtime);
    if (capability) issues.push(capability);
    if (account && bindings.accounts.some(other => {
      const declared = manifest.connections.find(c => c.id === other.connection);
      const sameLocation = 'base_url' in other && 'base_url' in account
        ? new URL(other.base_url).origin === new URL(account.base_url).origin
        : 'config_home' in other && 'config_home' in account && resolve(other.config_home) === resolve(account.config_home);
      return declared && sameLocation
        && `${declared.group}:${declared.account_ref}:${declared.provider}:${declared.billing}` !== `${connection.group}:${connection.account_ref}:${connection.provider}:${connection.billing}`;
    })) issues.push({ code: connection.transport === 'native' ? 'native_scope_conflict' : 'gateway_scope_conflict', message: 'A device credential reference cannot represent different account scopes' });
    return { profile: profile.id, runtime, group: connection.group, account_ref: connection.account_ref, status: issues.length ? 'blocked' : 'ready', manifest_fingerprint: digest(manifest), issues, credentials_checked: false, inference_checked: false };
  });
}

export function resolveProfile(manifest: ProfileManifest, bindings: DeviceBindings, options: { group: string; profile: string; runtime?: string }) {
  const report = doctorProfiles(manifest, bindings, options)[0];
  if (report.status !== 'ready') throw new Error(report.issues.map(i => `${i.code}: ${i.message}`).join('; '));
  return resolveConnection(bind(validateManifest(manifest), validateBindings(bindings), options), options);
}
export async function loadProfileSelection(manifest: string, bindings: string, options: { group: string; profile: string; runtime?: string }) {
  const files = await Promise.all([readFile(manifest, 'utf8'), readFile(bindings, 'utf8')]);
  return resolveProfile(validateManifest(JSON.parse(files[0])), validateBindings(JSON.parse(files[1])), options);
}

// This is a read-only preflight. Core dispatch rechecks current policy and the
// signed plan at execution; this result grants no authority or login proof.
export function resolveCoreSelection(manifest: ProfileManifest, bindings: DeviceBindings,
  options: { group: string; profile: string; runtime?: string }, core: { command: string; ledger: string; env?: NodeJS.ProcessEnv }) {
  const selection = resolveProfile(manifest, bindings, options);
  const connection = selection.connection;
  if (connection.transport !== 'native' || !connection.core_account) throw new Error('Native Core resolution requires an explicit host/account binding');
  if (!core.command.startsWith('/') || !core.ledger.startsWith('/') || /[\x00-\x1f\x7f]/u.test(core.command + core.ledger)) throw new Error('Core executable and operator ledger must be absolute references');
  const source = core.env ?? process.env;
  const env: NodeJS.ProcessEnv = {};
  for (const key of ['PATH', 'HOME', 'USER', 'LANG', 'LC_ALL', 'TMPDIR', 'HARNESS_SSH_KEYGEN']) if (source[key] !== undefined) env[key] = source[key];
  const read = (resource: string, args: string[]) => {
    const output = spawnSync(core.command, ['--json', resource, '--ledger', core.ledger, ...args], { env, encoding: 'utf8', timeout: 30000, maxBuffer: 1048576 });
    if (output.error || output.status !== 0) throw new Error(`Cannot confirm the current Core ${resource} registry`);
    try { return JSON.parse(output.stdout); } catch { throw new Error(`Invalid Core ${resource} response`); }
  };
  const reference = connection.core_account;
  const view = read('account', ['show', reference.id]);
  const provider = connection.provider === 'openai' ? 'codex' : 'claude';
  if (view?.account?.id !== reference.id || view?.account?.host !== reference.host || view?.account?.provider !== provider
    || view?.account?.identity_verified !== true || view?.classification?.status !== 'assigned' || view?.classification?.group !== options.group) throw new Error('Core account must be verified in the selected host, provider and group');
  const environments = read('environment', ['list']);
  if (!Array.isArray(environments) || environments.filter(e => e?.environment?.spec?.name === reference.host && e?.environment?.lifecycle === 'active').length !== 1) throw new Error('Core host must be registered and active');
  return {
    schema_version: 1, execution: 'not_started', registry_checked: true, credentials_checked: false, inference_checked: false,
    manifest_fingerprint: doctorProfiles(manifest, bindings, options)[0].manifest_fingerprint,
    selection_fingerprint: selection.fingerprint, account_ref: connection.account_ref, model: connection.models.main.id,
    dispatch: { host: reference.host, account: reference.id, group: options.group, provider,
      runtime: selection.runtime === 'claude-code' ? 'claude' : selection.runtime,
      runtime_version: selection.engine.version, profile: selection.profile, config_home: connection.config_home },
    runtime_command: selection.engine.command, runtime_args: nativeArguments(connection, selection.runtime),
  };
}

if (import.meta.main) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const flags = argumentsFor(args, ['manifest', 'bindings', 'profile', 'group', 'runtime', 'core', 'operator-ledger']);
    if (!flags.manifest || !flags.group) throw new Error('Explicit manifest and group are required');
    if (command !== 'resolve-core' && (flags.core || flags['operator-ledger'])) throw new Error('Core references are only used by resolve-core');
    const manifest = validateManifest(JSON.parse(await readFile(flags.manifest, 'utf8')));
    if (command === 'list' && !flags.bindings && !flags.runtime && !flags.profile) console.log(JSON.stringify(manifest.profiles.filter(p => manifest.connections.find(c => c.id === p.connection)?.group === flags.group), null, 2));
    else if (command === 'doctor' && flags.bindings) {
      const report = doctorProfiles(manifest, validateBindings(JSON.parse(await readFile(flags.bindings, 'utf8'))), { group: flags.group, profile: flags.profile, runtime: flags.runtime });
      console.log(JSON.stringify(report, null, 2));
      if (report.some(p => p.status === 'blocked')) process.exitCode = 1;
    } else if (command === 'resolve' && flags.bindings && flags.profile) console.log(JSON.stringify(await loadProfileSelection(flags.manifest, flags.bindings, { group: flags.group, profile: flags.profile, runtime: flags.runtime }), null, 2));
    else if (command === 'resolve-core' && flags.bindings && flags.profile && flags.core && flags['operator-ledger']) {
      const bindings = validateBindings(JSON.parse(await readFile(flags.bindings, 'utf8')));
      console.log(JSON.stringify(resolveCoreSelection(manifest, bindings, { group: flags.group, profile: flags.profile, runtime: flags.runtime }, { command: flags.core, ledger: flags['operator-ledger'] }), null, 2));
    }
    else throw new Error('Use list|doctor|resolve with --manifest <file> --group <group> and device bindings, or resolve-core with --profile <id> --core <absolute-executable> --operator-ledger <absolute-ledger>');
  } catch (error) { console.error((error as Error).message); process.exitCode = 2; }
}
