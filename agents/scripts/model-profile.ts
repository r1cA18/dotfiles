import { createHash } from 'node:crypto';
import { readFile, realpath } from 'node:fs/promises';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

export type Runtime = 'api' | 'codex' | 'claude';
interface Profile {
  id: string;
  revision: number;
  provider: string;
  models: string[];
  prompt: string;
  sources: string[];
  behavior_validation: string;
  runtime_notes: string[];
}
interface Source { url: string; kind: string; note: string; checked_at: string }
interface Registry {
  schema_version: number;
  release: string;
  status: string;
  reviewed_at: string;
  review_due: string;
  common: string;
  profiles: Profile[];
}
const defaultDirectory = join(dirname(fileURLToPath(import.meta.url)), '../model-profiles/v1');
const digest = (text: string) => `sha256:${createHash('sha256').update(text).digest('hex')}`;

async function asset(directory: string, name: string): Promise<string> {
  if (!/^[a-z0-9-]+\.(md|json)$/.test(name)) throw new Error('Invalid profile asset name');
  const root = await realpath(directory);
  const path = await realpath(join(root, name));
  const rel = relative(root, path);
  if (rel.startsWith('..') || rel.includes('/')) throw new Error('Profile asset escapes catalog');
  return readFile(path, 'utf8');
}

export async function loadCatalog(directory = defaultDirectory) {
  const registryText = await asset(directory, 'registry.json');
  const sourcesText = await asset(directory, 'sources.json');
  const registry = JSON.parse(registryText) as Registry;
  const sources = JSON.parse(sourcesText) as Record<string, Source>;
  if (registry.schema_version !== 1 || !Array.isArray(registry.profiles) || !registry.release) {
    throw new Error('Unsupported model profile registry');
  }
  const ids = new Set<string>();
  const models = new Set<string>();
  for (const profile of registry.profiles) {
    if (!/^[a-z0-9-]+$/.test(profile.id) || ids.has(profile.id) || !Number.isInteger(profile.revision) || profile.revision < 1) {
      throw new Error('Invalid or duplicate profile ID');
    }
    ids.add(profile.id);
    if (!profile.provider || !profile.models?.length || !profile.sources?.length ||
        !['not_run', 'passed', 'failed'].includes(profile.behavior_validation) || !Array.isArray(profile.runtime_notes)) {
      throw new Error(`Invalid profile: ${profile.id}`);
    }
    for (const model of profile.models) {
      const key = `${profile.provider}:${model}`;
      if (typeof model !== 'string' || !model || models.has(key)) throw new Error('Ambiguous model mapping');
      models.add(key);
    }
    for (const id of profile.sources) {
      if (!sources[id] || !/^https:\/\//.test(sources[id].url)) throw new Error(`Missing source: ${id}`);
    }
    const prompt = await asset(directory, profile.prompt);
    if (!prompt.trim() || Buffer.byteLength(prompt) > 2400) throw new Error('Model addendum must stay short');
  }
  return { registry, sources, registryText, sourcesText, directory };
}

export async function compileProfile(options: {
  provider: string;
  model: string;
  runtime: Runtime;
  shared?: string;
  workspace?: string;
  project?: string;
  existingAddendum?: string;
  context?: string;
  task?: string;
  directory?: string;
}) {
  const catalog = await loadCatalog(options.directory);
  const profile = catalog.registry.profiles.find((p) => p.provider === options.provider && p.models.includes(options.model));
  if (!profile) throw new Error(`No reviewed profile for ${options.provider}:${options.model}`);
  if (!['api', 'codex', 'claude'].includes(options.runtime)) throw new Error('Unknown runtime');
  if ((options.runtime === 'codex' && options.provider !== 'openai') ||
      (options.runtime === 'claude' && options.provider !== 'anthropic')) {
    throw new Error('Native runtime/provider combination is not verified');
  }
  if (options.runtime !== 'api' && (options.shared || options.project || options.workspace)) {
    throw new Error('Native runtimes load policy files themselves; do not duplicate them in an addendum');
  }
  const common = await asset(catalog.directory, catalog.registry.common);
  const modelPrompt = await asset(catalog.directory, profile.prompt);
  const layers = [
    ['common', common], ['model', modelPrompt],
    ['shared', options.shared ?? ''], ['workspace', options.workspace ?? ''],
    ['project', options.project ?? ''], ['existing-addendum', options.existingAddendum ?? ''],
  ].filter(([, text]) => text.trim());
  const instructions = layers.map(([name, text]) => `## ${name}\n${text.trim()}`).join('\n\n');
  // Source context and the current user task stay outside privileged instructions.
  // JSON escaping prevents forged section delimiters from changing this structure.
  const userInput = JSON.stringify({ source_context: options.context ?? '', task: options.task ?? '' });
  const locations: Record<string, string> = {
    openai: 'developer message', anthropic: 'top-level system', google: 'systemInstruction',
  };
  const binding = options.runtime === 'codex'
    ? { location: 'developer_instructions', mode: 'append', merge_existing_required: true }
    : options.runtime === 'claude'
      ? { location: '--append-system-prompt', mode: 'append', merge_existing_required: true }
      : { location: locations[options.provider] ?? 'system message', mode: 'compose', merge_existing_required: true };
  const payload = {
    schema_version: 1,
    profile: { id: profile.id, revision: profile.revision, release: catalog.registry.release },
    provider: options.provider, model: options.model, runtime: options.runtime,
    instructions, user_input: userInput, binding,
    manifest: {
      catalog_digest: digest(catalog.registryText), sources_digest: digest(catalog.sourcesText),
      layers: layers.map(([name, text]) => ({ name, digest: digest(text) })),
      user_input_digest: digest(userInput),
      sources: profile.sources.map((id) => ({ id, ...catalog.sources[id] })),
      reviewed_at: catalog.registry.reviewed_at, review_due: catalog.registry.review_due,
      behavior_validation: profile.behavior_validation, runtime_notes: profile.runtime_notes,
    },
  };
  return { ...payload, artifact_digest: digest(JSON.stringify(payload)) };
}

if (import.meta.main) {
  try {
    const args = process.argv.slice(2);
    const command = args.shift();
    if (command === 'list' && args.length === 0) {
      const { registry } = await loadCatalog();
      console.log(JSON.stringify(registry, null, 2));
    } else if (command === 'render') {
      const values: Record<string, string> = {};
      const allowed = new Set(['provider', 'model', 'runtime', 'shared', 'workspace', 'project', 'existing-addendum', 'context', 'task', 'format']);
      while (args.length) {
        const key = args.shift()?.replace(/^--/, '');
        const value = args.shift();
        if (!key || !allowed.has(key) || value === undefined || values[key]) throw new Error('Invalid or repeated argument');
        values[key] = value;
      }
      if (!values.provider || !values.model || !values.runtime) throw new Error('provider, model, and runtime are required');
      if (values.format && !['json', 'text'].includes(values.format)) throw new Error('Unknown output format');
      const read = async (key: string) => values[key] ? readFile(values[key], 'utf8') : undefined;
      const compiled = await compileProfile({
        provider: values.provider, model: values.model, runtime: values.runtime as Runtime,
        shared: await read('shared'), workspace: await read('workspace'), project: await read('project'),
        existingAddendum: await read('existing-addendum'), context: await read('context'), task: await read('task'),
      });
      console.log(values.format === 'text' ? compiled.instructions : JSON.stringify(compiled, null, 2));
    } else {
      throw new Error('Usage: model-profile.ts list | render --provider <id> --model <exact-id> --runtime <api|codex|claude> [--task <file>] [--context <file>] [--format <json|text>]');
    }
  } catch (error) {
    console.error((error as Error).message);
    process.exitCode = 1;
  }
}
