#!/usr/bin/env bun
import { readFile, realpath, stat } from "node:fs/promises";
import { isAbsolute, relative, resolve, sep } from "node:path";

export const KINDS = ["rule", "skill", "knowledge", "tool", "plugin", "stack-pack"] as const;
export type AssetKind = (typeof KINDS)[number];
export interface Asset {
  id: string;
  kind: AssetKind;
  title: string;
  summary: string;
  path: string;
  categories: string[];
}
export interface Catalog {
  $schema?: string;
  version: 1;
  taxonomy: string[];
  assets: Asset[];
}
export interface Selector {
  domain?: string;
  kind?: AssetKind;
  query?: string;
  limit?: number;
}

const CATEGORY = /^[a-z0-9]+(?:-[a-z0-9]+)*(?:\/[a-z0-9]+(?:-[a-z0-9]+)*)*$/;
const ID = /^(rule|skill|knowledge|tool|plugin|stack-pack):[a-z0-9]+(?:[.-][a-z0-9]+)*$/;
const repositoryRoot = resolve(import.meta.dir, "../..");

function record(value: unknown, label: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error(`${label} must be an object`);
  return value as Record<string, unknown>;
}

function keys(value: Record<string, unknown>, allowed: string[], label: string): void {
  for (const key of Object.keys(value)) {
    if (!allowed.includes(key)) throw new Error(`${label}: unknown field ${key}`);
  }
}

function text(value: unknown, label: string, maxLength: number): string {
  if (typeof value !== "string" || !value.trim() || value !== value.trim() || value.length > maxLength) {
    throw new Error(`${label} must be trimmed nonempty text of at most ${maxLength} characters`);
  }
  return value;
}

function strings(value: unknown, label: string): string[] {
  if (!Array.isArray(value) || value.some((item) => typeof item !== "string")) {
    throw new Error(`${label} must be an array of strings`);
  }
  if (new Set(value).size !== value.length) throw new Error(`${label} contains duplicates`);
  return value;
}

function within(path: string, root: string): boolean {
  const suffix = relative(root, path);
  return suffix !== ".." && !suffix.startsWith(`..${sep}`) && !isAbsolute(suffix);
}

export async function validateCatalog(value: unknown, root: string): Promise<Catalog> {
  const input = record(value, "catalog");
  keys(input, ["$schema", "version", "taxonomy", "assets"], "catalog");
  if (input.$schema !== undefined && typeof input.$schema !== "string") throw new Error("$schema must be a string");
  if (input.version !== 1) throw new Error("unsupported catalog version");
  const taxonomy = strings(input.taxonomy, "taxonomy");
  const categories = new Set(taxonomy);
  for (const category of taxonomy) {
    if (!CATEGORY.test(category)) throw new Error(`invalid taxonomy path: ${category}`);
    const slash = category.lastIndexOf("/");
    if (slash >= 0 && !categories.has(category.slice(0, slash))) throw new Error(`missing taxonomy parent: ${category}`);
  }
  if (!Array.isArray(input.assets)) throw new Error("assets must be an array");
  const ids = new Set<string>();
  const paths = new Set<string>();
  const realRoot = await realpath(root);
  const assets: Asset[] = [];
  for (const [index, raw] of input.assets.entries()) {
    const label = `assets[${index}]`;
    const asset = record(raw, label);
    keys(asset, ["id", "kind", "title", "summary", "path", "categories"], label);
    const id = text(asset.id, `${label}.id`, 180);
    if (!ID.test(id)) throw new Error(`invalid asset ID: ${id}`);
    if (!KINDS.includes(asset.kind as AssetKind) || !id.startsWith(`${asset.kind}:`)) throw new Error(`asset kind mismatch: ${id}`);
    if (ids.has(id)) throw new Error(`duplicate asset ID: ${id}`);
    ids.add(id);
    const title = text(asset.title, `${label}.title`, 120);
    const summary = text(asset.summary, `${label}.summary`, 300);
    const path = text(asset.path, `${label}.path`, 4096);
    if (isAbsolute(path) || path.includes("\\") || path.split("/").some((part) => ["", ".", ".."].includes(part))) {
      throw new Error(`invalid repository-relative path: ${path}`);
    }
    const target = await realpath(resolve(realRoot, path)).catch(() => { throw new Error(`missing asset path: ${path}`); });
    if (!within(target, realRoot)) throw new Error(`asset path leaves repository: ${path}`);
    if (!(await stat(target)).isFile()) throw new Error(`asset path must identify a file: ${path}`);
    if (paths.has(target)) throw new Error(`duplicate asset path: ${path}`);
    paths.add(target);
    if (asset.kind === "skill" && !path.endsWith("/SKILL.md")) throw new Error(`skill path must identify SKILL.md: ${path}`);
    const assigned = strings(asset.categories, `${label}.categories`);
    if (!assigned.length) throw new Error(`asset categories must not be empty: ${id}`);
    for (const category of assigned) {
      if (!categories.has(category)) throw new Error(`unknown taxonomy category: ${category}`);
    }
    assets.push({ id, kind: asset.kind as AssetKind, title, summary, path, categories: assigned });
  }
  return { ...(typeof input.$schema === "string" ? { $schema: input.$schema } : {}), version: 1, taxonomy, assets };
}

export function selectAssets(catalog: Catalog, selector: Selector = {}): { assets: Asset[]; has_more: boolean } {
  const limit = selector.limit ?? 5;
  if (!Number.isInteger(limit) || limit < 1 || limit > 50) throw new Error("limit must be an integer between 1 and 50");
  if (selector.kind !== undefined && !KINDS.includes(selector.kind)) throw new Error(`unknown kind: ${selector.kind}`);
  if (selector.domain !== undefined && !catalog.taxonomy.includes(selector.domain)) throw new Error(`unknown domain: ${selector.domain}`);
  const terms = (selector.query ?? "").trim().toLowerCase().split(/\s+/).filter(Boolean);
  const matches = catalog.assets.filter((asset) => {
    if (selector.kind && asset.kind !== selector.kind) return false;
    if (selector.domain && !asset.categories.some((category) => category === selector.domain || category.startsWith(`${selector.domain}/`))) return false;
    const searchable = [asset.id, asset.title, asset.summary, ...asset.categories].join(" ").toLowerCase();
    return terms.every((term) => searchable.includes(term));
  }).sort((left, right) => left.id < right.id ? -1 : left.id > right.id ? 1 : 0);
  return { assets: matches.slice(0, limit), has_more: matches.length > limit };
}

export async function run(argv: string[], root = repositoryRoot): Promise<void> {
  const [command, ...args] = argv;
  if (command !== "validate" && command !== "select") throw new Error("usage: asset-catalog.ts validate|select [--catalog FILE] [--domain PATH] [--kind KIND] [--query TEXT] [--limit 1..50]");
  const options = new Map<string, string>();
  const allowed = command === "validate" ? ["--catalog"] : ["--catalog", "--domain", "--kind", "--query", "--limit"];
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index]!;
    const value = args[index + 1];
    if (!allowed.includes(key) || options.has(key) || value === undefined || value.startsWith("--")) throw new Error(`invalid or repeated option: ${key}`);
    options.set(key, value);
  }
  const catalogPath = options.get("--catalog") ?? resolve(root, "agents/catalog/assets.json");
  const catalog = await validateCatalog(JSON.parse(await readFile(catalogPath, "utf8")), root);
  if (command === "validate") {
    console.log(`Validated ${catalog.assets.length} assets and ${catalog.taxonomy.length} taxonomy paths`);
    return;
  }
  const selected = selectAssets(catalog, {
    domain: options.get("--domain"),
    kind: options.get("--kind") as AssetKind | undefined,
    query: options.get("--query"),
    limit: options.has("--limit") ? Number(options.get("--limit")) : undefined,
  });
  console.log(JSON.stringify({ version: 1, ...selected }, null, 2));
}

if (import.meta.main) {
  run(process.argv.slice(2)).catch((error: unknown) => {
    console.error(`asset-catalog: ${error instanceof Error ? error.message : String(error)}`);
    process.exitCode = 1;
  });
}
