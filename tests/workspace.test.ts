import { afterEach, expect, test } from "bun:test";
import { cpSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const roots: string[] = [];
const script = resolve("agents/scripts/workspace.ts");
const binary = process.env.INDEXION_BIN;

afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "workspace-test-"));
  roots.push(root);
  const home = join(root, "home");
  const ghqRoot = join(root, "checkouts");
  const workspace = join(root, "project");
  mkdirSync(home);
  mkdirSync(workspace);
  cpSync(resolve("templates/workspace"), workspace, { recursive: true });
  // Preserve coverage of workspaces generated before local checkout support.
  rmSync(join(workspace, "workspace.json"));
  const env = { ...process.env, HOME: home, GIT_CONFIG_GLOBAL: join(home, ".gitconfig"), GIT_CONFIG_NOSYSTEM: "1", GHQ_ROOT: ghqRoot };
  const cmd = (args: string[], cwd = workspace) => {
    const result = Bun.spawnSync(args, { cwd, env, stdout: "pipe", stderr: "pipe" });
    return { code: result.exitCode, out: result.stdout.toString(), err: result.stderr.toString() };
  };
  expect(cmd(["git", "config", "--global", "ghq.root", ghqRoot]).code).toBe(0);
  for (const alias of ["web", "api"]) {
    const repo = join(ghqRoot, `github.com/example/${alias}`);
    mkdirSync(repo, { recursive: true });
    cmd(["git", "init", "-q"], repo);
    writeFileSync(join(repo, "auth.ts"), `/** Refresh authentication token for ${alias}. */\nexport function refresh${alias}Token(token: string): string { return token + "fresh"; }\n`);
    writeFileSync(join(repo, ".gitignore"), "node_modules/\n.env\n");
    mkdirSync(join(repo, "node_modules"));
    writeFileSync(join(repo, "node_modules/ignored.ts"), "export function ignoredDependencyToken() { return 'dependency'; }\n");
    writeFileSync(join(repo, ".env"), "DO_NOT_INDEX_SECRET=authentication\n");
    cmd(["git", "add", "auth.ts", ".gitignore"], repo);
    expect(cmd(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "fixture"], repo).code).toBe(0);
  }
  writeFileSync(join(workspace, "repos.json"), JSON.stringify({ web: "github.com/example/web", api: "github.com/example/api" }));
  const ws = (...args: string[]) => cmd([process.execPath, script, ...args]);
  return { root, workspace, ghqRoot, ws, cmd, env };
}

test("sync is idempotent and rg searches both repos without dependencies", () => {
  const { ws } = fixture();
  expect(ws("sync").code).toBe(0);
  expect(ws("sync").code).toBe(0);
  const result = ws("rg", "-n", "Token");
  expect(result.code).toBe(0);
  expect(result.out).toContain("repos/web/auth.ts");
  expect(result.out).toContain("repos/api/auth.ts");
  expect(result.out).not.toContain("ignoredDependency");
});

test("snapshot verifies clean revisions and rejects changed files", () => {
  const { ws, workspace, ghqRoot } = fixture();
  expect(ws("sync").code).toBe(0);
  expect(ws("snapshot").code).toBe(0);
  expect(ws("verify").code).toBe(0);
  const lock = readFileSync(join(workspace, "repos.lock.json"), "utf8");
  writeFileSync(join(ghqRoot, "github.com/example/api/untracked.txt"), "changed");
  expect(ws("snapshot").code).toBe(1);
  expect(ws("verify").code).toBe(1);
  expect(readFileSync(join(workspace, "repos.lock.json"), "utf8")).toBe(lock);
});

test("invalid manifest and existing non-link paths are rejected", () => {
  const { ws, workspace } = fixture();
  mkdirSync(join(workspace, "repos/web"), { recursive: true });
  expect(ws("sync").err).toContain("Refusing to replace");
  writeFileSync(join(workspace, "repos.json"), JSON.stringify({ "../escape": "github.com/example/web" }));
  expect(ws("sync").err).toContain("Invalid repository");
});

test("init creates a standalone template and refuses to overwrite it", () => {
  const { root, ws } = fixture();
  const target = join(root, "new workspace");
  expect(ws("init", target).code).toBe(0);
  expect(readFileSync(join(target, "nix/indexion.nix"), "utf8")).toContain('version = "0.18.0"');
  expect(readFileSync(join(target, "scripts/workspace.ts"), "utf8")).toContain("function main()");
  expect(ws("init", target).code).toBe(1);
});

test("manifest changes cannot relabel an old checkout", () => {
  const { ws, workspace } = fixture();
  expect(ws("sync").code).toBe(0);
  writeFileSync(join(workspace, "repos.json"), JSON.stringify({ web: "github.com/example/api" }));
  expect(ws("snapshot").err).toContain("Manifest/link mismatch");
  expect(ws("codex").err).toContain("Manifest/link mismatch");
});

test("symlinked repos directory and snapshot output are rejected", () => {
  const { ws, workspace, root } = fixture();
  const outside = join(root, "outside");
  mkdirSync(outside);
  symlinkSync(outside, join(workspace, "repos"));
  expect(ws("sync").err).toContain("real directory");
  rmSync(join(workspace, "repos"));
  expect(ws("sync").code).toBe(0);
  writeFileSync(join(outside, "keep.txt"), "keep");
  symlinkSync(join(outside, "keep.txt"), join(workspace, "repos.lock.json"));
  expect(ws("snapshot").err).toContain("non-regular");
  expect(readFileSync(join(outside, "keep.txt"), "utf8")).toBe("keep");
});

test("Claude prompt precedes its variadic additional-directory option", () => {
  const { ws, root, env } = fixture();
  const bin = join(root, "bin");
  mkdirSync(bin);
  writeFileSync(join(bin, "claude"), `#!${process.execPath}\nconsole.log(JSON.stringify(process.argv.slice(2)));\n`, { mode: 0o755 });
  env.PATH = `${bin}:${env.PATH}`;
  expect(ws("sync").code).toBe(0);
  const result = ws("claude", "fix this", "--model", "sonnet");
  expect(result.code).toBe(0);
  const args = JSON.parse(result.out);
  expect(args.slice(0, 4)).toEqual(["fix this", "--model", "sonnet", "--add-dir"]);
});

function localFixture() {
  const context = fixture();
  const { workspace, ghqRoot, cmd, root, env } = context;
  writeFileSync(join(workspace, "workspace.json"), '{"checkout":"local"}\n');
  expect(cmd(["git", "config", "--global", `url.file://${ghqRoot}/github.com/example/.insteadOf`, "https://github.com/example/"]).code).toBe(0);
  expect(cmd(["git", "config", "--global", "--add", `url.file://${ghqRoot}/github.com/example/.insteadOf`, "git@github.com:example/"]).code).toBe(0);
  // Only Git and Bun are on PATH: core commands must not need Nix or ghq.
  const bin = join(root, "core-bin");
  mkdirSync(bin);
  symlinkSync(Bun.which("git")!, join(bin, "git"));
  symlinkSync(process.execPath, join(bin, "bun"));
  env.PATH = bin;
  return context;
}

function profileFixture() {
  const context = localFixture();
  const { cmd, env, ws } = context;
  expect(cmd(["git", "init", "-q"]).code).toBe(0);
  expect(ws("sync").code).toBe(0);
  for (const manager of ["cxp", "clp"]) {
    writeFileSync(join(env.PATH!, manager), `#!${process.execPath}
const args = process.argv.slice(2);
if (args[0] === "list") console.log("PROFILE\\tEMAIL\\tPATH\\ndefault\\towner@example.invalid\\t/tmp/default\\nwork\\twork@example.invalid\\t/tmp/work");
else if (args[0] === "path") { if (process.env.PROFILE_GONE) process.exit(1); console.log("/tmp/" + args[1]); }
else if (args[0] === "run") {
  if (process.env.PROFILE_GONE) process.exit(1);
  console.log(JSON.stringify({ manager: ${JSON.stringify(manager)}, args, memory: process.env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD }));
} else process.exit(2);
`, { mode: 0o755 });
  }
  writeFileSync(join(env.PATH!, "fzf"), `#!${process.execPath}
if (process.env.PICK_CANCEL) process.exit(130);
const rows = (await Bun.stdin.text()).trimEnd().split("\\n");
console.log(rows[process.env.PICK_DEFAULT ? 0 : 1]);
`, { mode: 0o755 });
  return context;
}

test("workspace profiles persist separately and route launches through account managers", () => {
  const { ws, cmd, workspace, env } = profileFixture();
  expect(ws("profile", "codex").code).toBe(0);
  env.PICK_DEFAULT = "1";
  expect(ws("profile", "claude").code).toBe(0);
  expect(ws("profile").out).toContain("codex: work\nclaude: default");
  const codex = JSON.parse(ws("codex", "fix this").out);
  expect(codex.manager).toBe("cxp");
  expect(codex.args.slice(0, 4)).toEqual(["run", "work", "-C", realpathSync(workspace)]);
  expect(codex.args.at(-1)).toBe("fix this");
  expect(codex.args.filter((arg: string) => arg === "--add-dir")).toHaveLength(2);
  const claude = JSON.parse(ws("claude", "fix this", "--model", "sonnet").out);
  expect(claude.manager).toBe("clp");
  expect(claude.args.slice(0, 6)).toEqual(["run", "default", "fix this", "--model", "sonnet", "--add-dir"]);
  expect(claude.memory).toBe("1");
  expect(cmd(["git", "config", "--local", "--get", "workspace.codexProfile"]).out.trim()).toBe("work");
  expect(cmd(["git", "status", "--porcelain", "--untracked-files=all"]).out).not.toContain("profile");
  expect(readFileSync(join(workspace, "workspace.json"), "utf8")).not.toContain("work@example");
});

test("profile cancellation and stale selections preserve settings without launching another account", () => {
  const { ws, env } = profileFixture();
  expect(ws("profile", "codex").code).toBe(0);
  env.PICK_CANCEL = "1";
  expect(ws("profile", "codex").code).toBe(0);
  expect(ws("profile").out).toContain("codex: work");
  delete env.PICK_CANCEL;
  env.PICK_DEFAULT = "1";
  env.PROFILE_GONE = "1";
  expect(ws("profile", "codex").code).toBe(1);
  expect(ws("profile").out).toContain("codex: work");
  expect(ws("codex").code).toBe(1);
  rmSync(join(env.PATH!, "cxp"));
  expect(ws("codex").err).toContain("cxp is required");
  expect(ws("profile", "codex", "--clear").code).toBe(0);
  expect(ws("profile", "codex", "--clear").code).toBe(0);
});

test("real fzf selects a registered workspace profile", () => {
  const { ws, env } = profileFixture();
  rmSync(join(env.PATH!, "fzf"));
  symlinkSync(Bun.which("fzf")!, join(env.PATH!, "fzf"));
  env.FZF_DEFAULT_OPTS = "--filter=work@example.invalid";
  expect(ws("profile", "codex").code).toBe(0);
  expect(ws("profile").out).toContain("codex: work");
});

test("clearing a profile restores environment inheritance and ignores ancestor settings", () => {
  const { ws, cmd, env, workspace } = profileFixture();
  writeFileSync(join(env.PATH!, "codex"), `#!${process.execPath}\nconsole.log(process.env.CODEX_HOME);\n`, { mode: 0o755 });
  env.CODEX_HOME = "/tmp/inherited-account";
  expect(ws("profile", "codex").code).toBe(0);
  expect(ws("profile", "codex", "--clear").code).toBe(0);
  expect(ws("codex").out.trim()).toBe(env.CODEX_HOME);
  expect(ws("profile", "codex").code).toBe(0);
  const nested = join(workspace, "nested");
  mkdirSync(nested);
  writeFileSync(join(nested, "repos.json"), "{}");
  writeFileSync(join(nested, "workspace.json"), '{"checkout":"local"}');
  expect(cmd([process.execPath, script, "profile", "codex"], nested).err).toContain("Not a repository root");
  expect(cmd([process.execPath, script, "codex"], nested).out.trim()).toBe(env.CODEX_HOME);
  expect(ws("profile", "unknown").err).toContain("Usage:");
});

test("local sync clones all repos with only Git and Bun and preserves local work", () => {
  const { ws, workspace, cmd } = localFixture();
  expect(ws("sync").code).toBe(0);
  writeFileSync(join(workspace, "repos/web/local.txt"), "keep");
  expect(ws("sync").code).toBe(0);
  expect(ws("status").out).toContain("local.txt");
  expect(readFileSync(join(workspace, "repos/web/local.txt"), "utf8")).toBe("keep");
  expect(cmd(["git", "init", "-q"]).code).toBe(0);
  expect(cmd(["git", "status", "--porcelain"]).out).not.toContain("repos/");
  expect(ws("snapshot").code).toBe(1);
  rmSync(join(workspace, "repos/web/local.txt"));
  expect(ws("snapshot").code).toBe(0);
  expect(ws("verify").code).toBe(0);
});

test("add supports HTTPS and SSH URLs, rejects duplicates, and remove keeps checkout", () => {
  const { ws, workspace } = localFixture();
  writeFileSync(join(workspace, "repos.json"), "{}\n");
  expect(ws("status").code).toBe(0);
  expect(ws("rg", "anything").err).toContain("Add repositories");
  expect(ws("add", "https://github.com/example/web", "client").code).toBe(0);
  expect(ws("add", "git@github.com:example/api").code).toBe(0);
  expect(ws("add", "ssh://git@github.com/example/web.git", "duplicate").err).toContain("Duplicate repository");
  expect(ws("remove", "client").code).toBe(0);
  expect(readFileSync(join(workspace, "repos/client/auth.ts"), "utf8")).toContain("refreshwebToken");
  expect(ws("add", "https://github.com/example/web", "client").code).toBe(0);
});

test("local checkout validates origins and preflights every path before cloning", () => {
  const { ws, workspace, cmd } = localFixture();
  expect(ws("sync").code).toBe(0);
  expect(cmd(["git", "-C", "repos/web", "remote", "set-url", "origin", "https://github.com/example/other"]).code).toBe(0);
  expect(ws("codex").err).toContain("Manifest/origin mismatch");
  expect(ws("sync").err).toContain("Manifest/origin mismatch");
  writeFileSync(join(workspace, "repos.json"), JSON.stringify({ missing: "github.com/example/missing", web: "github.com/example/web" }));
  expect(ws("sync").err).toContain("Manifest/origin mismatch");
  expect(() => readFileSync(join(workspace, "repos/missing/.git/config"))).toThrow();
});

test("invalid URLs and case-colliding aliases cannot mutate the manifest", () => {
  const { ws, workspace } = localFixture();
  const before = readFileSync(join(workspace, "repos.json"), "utf8");
  for (const url of ["--upload-pack=command", "https://github.com/example/../other", "https://github.com/example/%2e%2e/other/repo", "https://github.com:443/example/repo", "https://user:secret@github.com/example/repo", "file:///tmp/repo"]) {
    expect(ws("add", url, "extra").code).toBe(1);
    expect(readFileSync(join(workspace, "repos.json"), "utf8")).toBe(before);
  }
  expect(ws("add", "github.com/example/other", "Web").err).toContain("case-insensitive");
  expect(readFileSync(join(workspace, "repos.json"), "utf8")).toBe(before);
});

test("standalone workspace clone restores children without executing downloaded scripts", () => {
  const { ws, cmd, ghqRoot, root, workspace } = localFixture();
  const shared = join(ghqRoot, "github.com/example/shared");
  expect(ws("init", shared).code).toBe(0);
  cpSync(join(workspace, "repos.json"), join(shared, "repos.json"));
  writeFileSync(join(shared, "ws"), "#!/bin/sh\nexit 99\n");
  expect(cmd(["git", "add", "."], shared).code).toBe(0);
  expect(cmd(["git", "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "-qm", "workspace"], shared).code).toBe(0);
  const target = join(root, "onboarding/team project");
  expect(ws("clone", "https://github.com/example/shared", target).code).toBe(0);
  expect(readFileSync(join(target, "repos/api/auth.ts"), "utf8")).toContain("refreshapiToken");
  expect(ws("clone", "https://github.com/example/shared", target).code).toBe(1);
  expect(cmd([process.execPath, join(target, "scripts/workspace.ts"), "status"], target).code).toBe(0);
});

test.skipIf(!process.env.WORKSPACE_BIN)("packaged init creates writable files and a working standalone entrypoint", () => {
  const { cmd, root, env } = localFixture();
  const target = join(root, "packaged workspace");
  const result = cmd([process.env.WORKSPACE_BIN!, "init", target]);
  expect(result.code, result.err).toBe(0);
  for (const file of ["repos.json", "workspace.json", "AGENTS.md", "scripts/workspace.ts", "nix/indexion.nix", "ws"]) {
    expect(statSync(join(target, file)).mode & 0o200, `${file} must be owner-writable`).toBe(0o200);
  }
  expect(statSync(join(target, "ws")).mode & 0o100).toBe(0o100);
  // Exercise the shared shell entrypoint from outside its workspace.
  symlinkSync("/bin/bash", join(env.PATH!, "bash"));
  const added = cmd([join(target, "ws"), "add", "https://github.com/example/web", "client"], root);
  expect(added.code, added.err).toBe(0);
  expect(cmd([join(target, "ws"), "snapshot"], root).code).toBe(0);
  expect(cmd([join(target, "ws"), "verify"], root).code).toBe(0);
});

for (const mode of ["ghq", "local"] as const) {
test.skipIf(!binary)(`real indexion searches both repos and builds ${mode} function indexes`, () => {
  const { ws, cmd, workspace } = fixture();
  if (mode === "local") {
    writeFileSync(join(workspace, "workspace.json"), '{"checkout":"local"}\n');
    const root = cmd(["ghq", "root"]).out.trim();
    expect(cmd(["git", "config", "--global", `url.file://${root}/github.com/example/.insteadOf`, "https://github.com/example/"]).code).toBe(0);
  }
  expect(ws("sync").code).toBe(0);
  writeFileSync(join(workspace, "docs/knowledge/auth.md"), "# Authentication contract\n\nBoth clients refresh authentication tokens using the auth API.\n");
  const wiki = cmd([binary!, "wiki", "pages", "add", "--id=authentication", "--title=Authentication contract", "--content=docs/knowledge/auth.md", "--sources=repos/web/auth.ts,repos/api/auth.ts", "--provenance=manual"]);
  expect(wiki.code, wiki.err).toBe(0);
  const index = ws("index");
  expect(index.code, index.err).toBe(0);
  const search = ws("search", "authentication token");
  expect(search.code).toBe(0);
  expect(search.out).toContain("auth.ts");
  expect(search.out).toContain("web");
  expect(search.out).toContain("api");
  expect(search.out).not.toContain("DO_NOT_INDEX_SECRET");
  expect(search.out).not.toContain("ignoredDependency");
  expect(search.out).toContain("Authentication contract");
  const query = ws("query", "refresh authentication token");
  expect(query.code, query.err).toBe(0);
  expect(query.out).toContain("refreshwebToken");
  expect(query.out).toContain("refreshapiToken");
  const orient = ws("orient", "refresh authentication token");
  expect(orient.code, orient.err).toBe(0);
  expect(orient.out).toContain("auth.ts");
}, 60_000);
}
