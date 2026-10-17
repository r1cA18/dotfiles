import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { argumentsFor, gatewayIssue, runtimeCommands, validateCatalog, resolveConnection, type Catalog, type Connection, type Runtime } from './model-connection';

// Portable intent stays in Git. Executable locations and gateway origins stay
// on the device. Neither document contains credentials or native account state.
export interface ProfileManifest extends Omit<Catalog, 'runtimes' | 'connections'> {
  runtimes: Partial<Record<Runtime, { version: string }>>;
  connections: Omit<Connection, 'base_url'>[];
}
export interface DeviceBindings {
  schema_version: 1;
  commands: Partial<Record<Runtime, string>>;
  accounts: { connection: string; group: string; account_ref: string; base_url: string }[];
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
  const connections = m.connections.map((item, index) => ({
    ...object(item, ['id', 'group', 'provider', 'account_ref', 'billing', 'transport', 'models']),
    base_url: `http://127.0.0.1:${10000 + index}`,
  }));
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
    const a = object(item, ['connection', 'group', 'account_ref', 'base_url']);
    const key = identifier(a.connection); identifier(a.group); identifier(a.account_ref);
    if (accounts.has(key)) throw new Error('Duplicate device account binding');
    accounts.add(key);
    if (typeof a.base_url !== 'string' || !a.base_url.length || /[\s\x00-\x1f\x7f]/u.test(a.base_url)) throw new Error('Invalid gateway origin');
    const url = new URL(a.base_url);
    if (url.protocol !== 'http:' || !['127.0.0.1', '[::1]'].includes(url.hostname) || url.username || url.password || url.search || url.hash || url.pathname !== '/') throw new Error('Use an unauthenticated loopback gateway origin');
  }
  return structuredClone(b) as unknown as DeviceBindings;
}

function bind(manifest: ProfileManifest, bindings: DeviceBindings, options: { profile: string; runtime?: string }): Catalog {
  const profile = manifest.profiles.find(p => p.id === options.profile)!;
  const connection = manifest.connections.find(c => c.id === profile.connection)!;
  const runtime = (options.runtime ?? profile.runtime ?? manifest.default_runtime) as Runtime;
  return validateCatalog({
    ...manifest,
    default_runtime: runtime,
    runtimes: { [runtime]: { ...manifest.runtimes[runtime], command: bindings.commands[runtime] } },
    profiles: [{ ...profile, runtime }],
    connections: [{ ...connection, base_url: bindings.accounts.find(a => a.connection === connection.id)!.base_url }],
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
    if (!account) issues.push({ code: 'account_binding_missing', message: 'Bind an account-specific loopback gateway on this device' });
    else if (account.group !== connection.group || account.account_ref !== connection.account_ref) issues.push({ code: 'account_binding_mismatch', message: 'Device account reference or group differs from the portable profile' });
    const capability = gatewayIssue(connection, runtime);
    if (capability) issues.push(capability);
    if (account && bindings.accounts.some(other => {
      const declared = manifest.connections.find(c => c.id === other.connection);
      return declared && new URL(other.base_url).origin === new URL(account.base_url).origin
        && `${declared.group}:${declared.account_ref}:${declared.provider}:${declared.billing}` !== `${connection.group}:${connection.account_ref}:${connection.provider}:${connection.billing}`;
    })) issues.push({ code: 'gateway_scope_conflict', message: 'A device gateway cannot represent different account scopes' });
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

if (import.meta.main) {
  try {
    const [command, ...args] = process.argv.slice(2);
    const flags = argumentsFor(args, ['manifest', 'bindings', 'profile', 'group', 'runtime']);
    if (!flags.manifest || !flags.group) throw new Error('Explicit manifest and group are required');
    const manifest = validateManifest(JSON.parse(await readFile(flags.manifest, 'utf8')));
    if (command === 'list' && !flags.bindings && !flags.runtime && !flags.profile) console.log(JSON.stringify(manifest.profiles.filter(p => manifest.connections.find(c => c.id === p.connection)?.group === flags.group), null, 2));
    else if (command === 'doctor' && flags.bindings) {
      const report = doctorProfiles(manifest, validateBindings(JSON.parse(await readFile(flags.bindings, 'utf8'))), { group: flags.group, profile: flags.profile, runtime: flags.runtime });
      console.log(JSON.stringify(report, null, 2));
      if (report.some(p => p.status === 'blocked')) process.exitCode = 1;
    } else if (command === 'resolve' && flags.bindings && flags.profile) console.log(JSON.stringify(await loadProfileSelection(flags.manifest, flags.bindings, { group: flags.group, profile: flags.profile, runtime: flags.runtime }), null, 2));
    else throw new Error('Use list --manifest <file> --group <group>, or doctor|resolve with --bindings <device-file> [--profile <id>]');
  } catch (error) { console.error((error as Error).message); process.exitCode = 2; }
}
