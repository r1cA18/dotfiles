import { afterEach, beforeAll, expect, test } from "bun:test";
import { existsSync, lstatSync, mkdtempSync, mkdirSync, readFileSync, readdirSync, readlinkSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const roots: string[] = [];
const repoRoot = resolve(import.meta.dir, "..");
const profileTest = test.skipIf(process.env.DOTFILES_TEST_NIX !== "1");
let binaries: Record<string, string>;

beforeAll(() => {
  if (process.env.DOTFILES_TEST_NIX !== "1") return;
  const config = process.platform === "darwin" && process.arch === "arm64"
    ? "darwinConfigurations.RMB.config.home-manager.users.r1ca18.home.packages"
    : process.platform === "linux" && process.arch === "x64"
      ? 'homeConfigurations."r1ca18@homelab".config.home.packages'
      : null;
  if (!config) throw new Error(`No profile test configuration for ${process.platform}/${process.arch}`);
  const result = Bun.spawnSync([
    "nix", "eval", "--no-write-lock-file", "--json",
    `path:${repoRoot}#${config}`,
    "--apply",
    'packages: builtins.listToAttrs (map (p: { name = p.name; value = { derivation = p.drvPath; output = p.outPath; }; }) (builtins.filter (p: builtins.elem (p.name or "") ["cxp" "clp"]) packages))',
  ]);
  if (result.exitCode !== 0) throw new Error(result.stderr.toString());
  const packages: Record<string, { derivation: string; output: string }> = JSON.parse(result.stdout.toString());
  expect(Object.keys(packages).sort()).toEqual(["clp", "cxp"]);
  const build = Bun.spawnSync([
    "nix", "build", "--no-link",
    ...Object.values(packages).map((pkg) => `${pkg.derivation}^*`),
  ]);
  if (build.exitCode !== 0) throw new Error(build.stderr.toString());
  binaries = Object.fromEntries(Object.entries(packages).map(([name, pkg]) => [name, join(pkg.output, "bin", name)]));
}, 120_000);

afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
});

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "agent-profile-test-"));
  roots.push(root);
  mkdirSync(join(root, ".local/bin"), { recursive: true });
  return root;
}

function run(root: string, manager: string, args: string[], extra: Record<string, string> = {}) {
  return Bun.spawnSync([binaries[manager], ...args], {
    env: {
      PATH: process.env.PATH!,
      HOME: root,
      XDG_STATE_HOME: join(root, ".local/state"),
      MOCK_LOG: join(root, "login-target"),
      ...extra,
    },
  });
}

function mockCli(root: string, product: "codex" | "claude") {
  // Unsigned fixture identity, generated locally rather than storing a token.
  const mockToken = ["header", Buffer.from(JSON.stringify({ email: "test@example.com" })).toString("base64url"), "signature"].join(".");
  const script = product === "codex"
    ? `#!/bin/sh
set -eu
target="\${CODEX_HOME:-$HOME/.codex}"
printf '%s' "$target" > "$MOCK_LOG"
mkdir -p "$target"
printf '%s' '${JSON.stringify({ tokens: { id_token: mockToken } })}' > "$target/auth.json"
`
    : `#!/bin/sh
set -eu
target="\${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
printf '%s' "$target" > "$MOCK_LOG"
mkdir -p "$target"
state="$target/.claude.json"
if [ -z "\${CLAUDE_CONFIG_DIR:-}" ]; then state="$HOME/.claude.json"; fi
printf '%s' '{"oauthAccount":{"emailAddress":"test@example.com"}}' > "$state"
`;
  writeFileSync(join(root, ".local/bin", product), script, { mode: 0o755 });
}

for (const [manager, product, variable, stateDir] of [
  ["cxp", "codex", "CODEX_HOME", "codex"],
  ["clp", "claude", "CLAUDE_CONFIG_DIR", "claude-code"],
] as const) {
  profileTest(`${manager} can inspect profiles before the native CLI is installed`, () => {
    const root = fixture();
    for (const args of [["help"], ["list"], ["complete"], ["path", "default"], ["doctor"]]) {
      const result = run(root, manager, args);
      expect(result.exitCode, result.stderr.toString()).toBe(0);
      expect(result.stderr.toString()).not.toContain("was not found");
    }
  });

  profileTest(`${manager} reports a missing native CLI when a launch needs it`, () => {
    const root = fixture();
    const result = run(root, manager, ["run", "default"]);
    expect(result.exitCode).not.toBe(0);
    expect(result.stderr.toString()).toContain("was not found");
  });

  profileTest(`${manager} default login ignores the enclosing account home`, () => {
    const root = fixture();
    mockCli(root, product);
    const result = run(root, manager, ["login", "default"], {
      [variable]: join(root, "another-account"),
    });
    expect(result.exitCode, result.stderr.toString()).toBe(0);
    expect(readFileSync(join(root, "login-target"), "utf8")).toBe(join(root, `.${product}`));
  });

  profileTest(`${manager} adds and runs an isolated account`, () => {
    const root = fixture();
    mockCli(root, product);
    const expected = join(root, ".local/state", stateDir, "profiles/test@example.com");
    const added = run(root, manager, ["add", "test@example.com"]);
    expect(added.exitCode, added.stderr.toString()).toBe(0);
    expect(readFileSync(join(root, "login-target"), "utf8")).toBe(expected);
    const started = run(root, manager, ["run", "test@example.com"]);
    expect(started.exitCode, started.stderr.toString()).toBe(0);
    expect(readFileSync(join(root, "login-target"), "utf8")).toBe(expected);
  });

  profileTest(`${manager} shares configuration while keeping credentials and sessions local`, () => {
    const root = fixture();
    mockCli(root, product);
    const primary = join(root, `.${product}`);
    mkdirSync(primary);
    mkdirSync(join(primary, "skills"));
    mkdirSync(join(primary, "sessions"));
    writeFileSync(join(primary, "sessions", "private-session"), "primary session");
    const added = run(root, manager, ["add", "test@example.com"]);
    expect(added.exitCode, added.stderr.toString()).toBe(0);
    const account = join(root, ".local/state", stateDir, "profiles/test@example.com");
    expect(readlinkSync(join(account, "skills"))).toBe(join(primary, "skills"));
    expect(existsSync(join(account, "sessions"))).toBe(false);
    expect(lstatSync(join(account, product === "codex" ? "auth.json" : ".claude.json")).isSymbolicLink()).toBe(false);

    rmSync(join(account, "skills"));
    mkdirSync(join(account, "skills"));
    writeFileSync(join(account, "skills", "keep.txt"), "local skill");
    const started = run(root, manager, ["run", "test@example.com"]);
    expect(started.exitCode).not.toBe(0);
    expect(readFileSync(join(account, "skills", "keep.txt"), "utf8")).toBe("local skill");
    expect(run(root, manager, ["doctor"]).exitCode).not.toBe(0);
  });

  profileTest(`${manager} refuses account mismatch before launching the CLI`, () => {
    const root = fixture();
    mockCli(root, product);
    expect(run(root, manager, ["add", "test@example.com"]).exitCode).toBe(0);
    const account = join(root, ".local/state", stateDir, "profiles/test@example.com");
    const metadata = product === "codex"
      ? { tokens: { id_token: `header.${Buffer.from('{"email":"other@example.com"}').toString("base64url")}.signature` } }
      : { oauthAccount: { emailAddress: "other@example.com" } };
    writeFileSync(join(account, product === "codex" ? "auth.json" : ".claude.json"), JSON.stringify(metadata));
    rmSync(join(root, "login-target"));
    const started = run(root, manager, ["run", "test@example.com"]);
    expect(started.exitCode).not.toBe(0);
    expect(existsSync(join(root, "login-target"))).toBe(false);
    expect(run(root, manager, ["doctor"]).exitCode).not.toBe(0);
  });

  profileTest(`${manager} archives recoverably and protects the default account`, () => {
    const root = fixture();
    mockCli(root, product);
    expect(run(root, manager, ["add", "test@example.com"]).exitCode).toBe(0);
    const state = join(root, ".local/state", stateDir);
    const account = join(state, "profiles/test@example.com");
    const metadataName = product === "codex" ? "auth.json" : ".claude.json";
    const credentials = readFileSync(join(account, metadataName), "utf8");
    writeFileSync(join(account, "session.txt"), "recoverable session");
    const archived = run(root, manager, ["archive", "test@example.com"]);
    expect(archived.exitCode, archived.stderr.toString()).toBe(0);
    expect(existsSync(account)).toBe(false);
    const entries = readdirSync(join(state, "trash"));
    expect(entries).toHaveLength(1);
    const recovered = join(state, "trash", entries[0]);
    expect(readFileSync(join(recovered, metadataName), "utf8")).toBe(credentials);
    expect(readFileSync(join(recovered, "session.txt"), "utf8")).toBe("recoverable session");
    expect(run(root, manager, ["archive", "default"]).exitCode).not.toBe(0);
  });
}
