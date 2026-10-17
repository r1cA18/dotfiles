import { afterEach, expect, test } from "bun:test";
import { mkdir, mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { KINDS, selectAssets, validateCatalog } from "./asset-catalog";

const roots: string[] = [];
afterEach(async () => {
  await Promise.all(roots.splice(0).map((root) => rm(root, { recursive: true, force: true })));
});

async function fixture() {
  const root = await mkdtemp(join(tmpdir(), "agent-asset-catalog-"));
  roots.push(root);
  await mkdir(join(root, "skills/example"), { recursive: true });
  await writeFile(join(root, "skills/example/SKILL.md"), "---\nname: example\ndescription: Example UI review.\n---\nBody must stay out of selection.\n");
  await writeFile(join(root, "rule.md"), "A rule is not a workflow.\n");
  return {
    root,
    value: {
      version: 1,
      taxonomy: ["engineering", "engineering/ui", "engineering/ui/web", "engineering/quality"],
      assets: [
        { id: "skill:example", kind: "skill", title: "Web review", summary: "Inspect UI accessibility", path: "skills/example/SKILL.md", categories: ["engineering/ui/web"] },
        { id: "rule:example", kind: "rule", title: "Engineering constraints", summary: "Always verify completed work", path: "rule.md", categories: ["engineering/quality"] },
      ],
    },
  };
}

test("maintained catalog validates and exposes only discovery metadata", async () => {
  const root = resolve(import.meta.dir, "../..");
  const value = JSON.parse(await readFile(join(root, "agents/catalog/assets.json"), "utf8"));
  const catalog = await validateCatalog(value, root);
  const selected = selectAssets(catalog, { kind: "skill", domain: "engineering/ui", limit: 2 });
  expect(selected.assets).toHaveLength(2);
  expect(selected.has_more).toBe(true);
  expect(selected.assets.every((asset) => asset.kind === "skill")).toBe(true);
  expect(Object.keys(selected.assets[0]!).sort()).toEqual(["categories", "id", "kind", "path", "summary", "title"]);
  const schema = JSON.parse(await readFile(join(root, "agents/catalog/schema.json"), "utf8"));
  expect(schema.$defs.asset.properties.kind.enum).toEqual([...KINDS]);
});

test("unknown categories and missing taxonomy parents fail validation", async () => {
  const { root, value } = await fixture();
  value.assets[0]!.categories = ["life/tax/jp"];
  await expect(validateCatalog(value, root)).rejects.toThrow("unknown taxonomy");
  value.taxonomy.push("life/tax/jp");
  await expect(validateCatalog(value, root)).rejects.toThrow("missing taxonomy parent");
});

test("duplicate taxonomy, category and asset IDs fail validation", async () => {
  const { root, value } = await fixture();
  const duplicateTaxonomy = structuredClone(value);
  duplicateTaxonomy.taxonomy.push("engineering");
  await expect(validateCatalog(duplicateTaxonomy, root)).rejects.toThrow("duplicates");
  const duplicateCategory = structuredClone(value);
  duplicateCategory.assets[0]!.categories.push("engineering/ui/web");
  await expect(validateCatalog(duplicateCategory, root)).rejects.toThrow("duplicates");
  value.assets.push({ ...value.assets[0]! });
  await expect(validateCatalog(value, root)).rejects.toThrow("duplicate asset ID");
});

test("IDs cannot change asset kind and unknown executable fields are rejected", async () => {
  const { root, value } = await fixture();
  value.assets[0]!.kind = "rule";
  await expect(validateCatalog(value, root)).rejects.toThrow("kind mismatch");
  value.assets[0]!.kind = "skill";
  await expect(validateCatalog({ ...value, permissions: ["send"] }, root)).rejects.toThrow("unknown field permissions");
  await expect(validateCatalog({ ...value, version: 2 }, root)).rejects.toThrow("unsupported catalog version");
});

test("dangling paths, directories, traversal and absolute paths fail validation", async () => {
  const { root, value } = await fixture();
  for (const [path, message] of [
    ["missing.md", "missing asset path"],
    ["skills", "must identify a file"],
    ["../outside.md", "invalid repository-relative path"],
    [join(root, "rule.md"), "invalid repository-relative path"],
    ["skills//example/SKILL.md", "invalid repository-relative path"],
  ]) {
    value.assets[0]!.path = path!;
    await expect(validateCatalog(value, root)).rejects.toThrow(message!);
  }
});

test("realpath checks reject outside symlinks and aliases to the same asset", async () => {
  const { root, value } = await fixture();
  const outside = await mkdtemp(join(tmpdir(), "agent-asset-outside-"));
  roots.push(outside);
  await writeFile(join(outside, "note.md"), "Private fixture only");
  await symlink(join(outside, "note.md"), join(root, "outside.md"));
  value.assets[1]!.path = "outside.md";
  await expect(validateCatalog(value, root)).rejects.toThrow("leaves repository");
  await symlink(join(root, "skills/example/SKILL.md"), join(root, "alias.md"));
  value.assets[1]!.path = "alias.md";
  await expect(validateCatalog(value, root)).rejects.toThrow("duplicate asset path");
});

test("a skill must reference its native entrypoint file", async () => {
  const { root, value } = await fixture();
  value.assets[0]!.path = "rule.md";
  await expect(validateCatalog(value, root)).rejects.toThrow("must identify SKILL.md");
});

test("selection composes domain descendants, kind and case insensitive query terms", async () => {
  const { root, value } = await fixture();
  const catalog = await validateCatalog(value, root);
  expect(selectAssets(catalog, { domain: "engineering/ui", kind: "skill", query: "WEB accessibility" }).assets.map((asset) => asset.id)).toEqual(["skill:example"]);
  expect(selectAssets(catalog, { domain: "engineering/ui", kind: "rule" }).assets).toEqual([]);
  expect(selectAssets(catalog, { query: "absent" }).assets).toEqual([]);
  expect(selectAssets(catalog, { query: "Body must stay out" }).assets).toEqual([]);
});

test("domain selection uses path segment boundaries and rejects unknown selectors", async () => {
  const { root, value } = await fixture();
  value.taxonomy.push("engineering/uikit");
  value.assets[1]!.categories = ["engineering/uikit"];
  const catalog = await validateCatalog(value, root);
  expect(selectAssets(catalog, { domain: "engineering/ui" }).assets.map((asset) => asset.id)).toEqual(["skill:example"]);
  expect(() => selectAssets(catalog, { domain: "engineering/missing" })).toThrow("unknown domain");
  expect(() => selectAssets(catalog, { kind: "unknown" as never })).toThrow("unknown kind");
  for (const limit of [0, -1, 51, 1.5, Number.NaN]) expect(() => selectAssets(catalog, { limit })).toThrow("limit");
});

test("selection stays bounded and deterministic without modifying the catalog", async () => {
  const { root, value } = await fixture();
  const catalog = await validateCatalog(value, root);
  const before = JSON.stringify(catalog);
  const selected = selectAssets(catalog, { domain: "engineering", limit: 1 });
  expect(selected.assets.map((asset) => asset.id)).toEqual(["rule:example"]);
  expect(selected.has_more).toBe(true);
  expect(JSON.stringify(catalog)).toBe(before);
});

test("selection order and limit prefixes stay invariant across catalog permutations", async () => {
  const root = resolve(import.meta.dir, "../..");
  const catalog = await validateCatalog(JSON.parse(await readFile(join(root, "agents/catalog/assets.json"), "utf8")), root);
  const baseline = selectAssets(catalog, { limit: 50 }).assets.map((asset) => asset.id);
  for (let offset = 0; offset < catalog.assets.length; offset++) {
    const rotated = [...catalog.assets.slice(offset), ...catalog.assets.slice(0, offset)];
    for (const assets of [rotated, [...rotated].reverse()]) {
      for (let limit = 1; limit <= baseline.length; limit++) {
        const selected = selectAssets({ ...catalog, assets }, { limit });
        expect(selected.assets.map((asset) => asset.id)).toEqual(baseline.slice(0, limit));
        expect(selected.has_more).toBe(limit < baseline.length);
      }
    }
  }
});

test("CLI rejects malformed and repeated options before returning any catalog", () => {
  const script = resolve(import.meta.dir, "asset-catalog.ts");
  for (const args of [[], ["select", "--limit", "2wrong"], ["select", "--kind", "skill", "--kind", "rule"], ["select", "--domain"], ["validate", "--query", "web"]]) {
    const result = Bun.spawnSync([process.execPath, script, ...args], { stdout: "pipe", stderr: "pipe" });
    expect(result.exitCode).toBe(1);
    expect(result.stdout.toString()).toBe("");
    expect(result.stderr.toString()).toContain("asset-catalog:");
  }
});
