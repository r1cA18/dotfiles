import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, realpathSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";

// Disposable integration fixture for the multi-repo workspace guide.
const root = mkdtempSync(join(tmpdir(), "workspace-check-"));
const workspace = join(root, "workspace");
const env = {
  ...process.env,
  DIRENV_CONFIG: join(root, "direnv-config"),
  XDG_DATA_HOME: join(root, "data"),
  XDG_CACHE_HOME: join(root, "cache"),
};

function run(cmd: string[], cwd = workspace) {
  const result = Bun.spawnSync(cmd, { cwd, env, stdout: "pipe", stderr: "pipe" });
  return {
    code: result.exitCode,
    out: result.stdout.toString().trim(),
    err: result.stderr.toString().trim(),
  };
}

function ok(cmd: string[], cwd = workspace) {
  const result = run(cmd, cwd);
  assert.equal(result.code, 0, `${cmd.join(" ")}: ${result.err}`);
  return result.out;
}

try {
  mkdirSync(join(workspace, "repos"), { recursive: true });
  ok(["git", "init", "--quiet"]);
  writeFileSync(join(workspace, "AGENTS.md"), "# Workspace\nRead repo-local instructions before editing.\n");
  writeFileSync(join(workspace, "CLAUDE.md"), "@AGENTS.md\n");
  writeFileSync(join(workspace, ".gitignore"), "/repos/\n");

  for (const name of ["web", "api"]) {
    const repo = join(root, "ghq", "github.com", "example", name);
    mkdirSync(join(repo, "vendor"), { recursive: true });
    ok(["git", "init", "--quiet"], repo);
    writeFileSync(join(repo, "main.txt"), `workspace_probe ${name}\n`);
    writeFileSync(join(repo, ".gitignore"), "/vendor/\n");
    writeFileSync(join(repo, "vendor", "generated.txt"), "workspace_probe ignored\n");
    writeFileSync(join(repo, "AGENTS.md"), `# ${name}\n${name}_instruction_probe\n`);
    writeFileSync(join(repo, ".envrc"), `export WORKSPACE_FIXTURE_ENV=${name}\n`);
    symlinkSync(repo, join(workspace, "repos", name), "dir");
  }

  const recursive = run(["rg", "--no-config", "-n", "workspace_probe", "repos/"]);
  assert.equal(recursive.code, 1);
  const followed = run(["rg", "--no-config", "-L", "-n", "workspace_probe", "repos/"]);
  assert.equal(followed.code, 0);
  assert.doesNotMatch(followed.out, /ignored/);
  assert.equal(run(["rg", "--no-config", "-L", "-n", "workspace_probe", "."]).code, 1);
  const explicit = ok(["rg", "--no-config", "-n", "workspace_probe", "repos/web/", "repos/api/"]);
  assert.match(explicit, /repos\/web\/main.txt:1:workspace_probe web/);
  assert.match(explicit, /repos\/api\/main.txt:1:workspace_probe api/);
  assert.doesNotMatch(explicit, /ignored/);
  console.log("PASS explicit repo search traverses links and respects each repo's ignore rules");

  for (const name of ["web", "api"]) {
    const link = join(workspace, "repos", name);
    const physical = realpathSync(link);
    assert.equal(ok(["git", "-C", link, "rev-parse", "--show-toplevel"]), physical);
    assert.notEqual(dirname(physical), workspace);
    assert.match(ok(["rg", "--no-config", "-n", `${name}_instruction_probe`, join(link, "AGENTS.md")]), /instruction_probe/);
    assert.equal(run(["direnv", "exec", physical, "true"]).code, 1);
    ok(["direnv", "allow", physical]);
    const values = ok(["direnv", "exec", physical, "env"]);
    assert.match(values, new RegExp(`^WORKSPACE_FIXTURE_ENV=${name}$`, "m"));
  }
  console.log("PASS links preserve independent Git roots and explicit instruction paths");
  console.log("PASS direnv requires trust and activates each repo's environment independently");

  const workspaceValues = ok(["direnv", "exec", workspace, "env"]);
  assert.doesNotMatch(workspaceValues, /^WORKSPACE_FIXTURE_ENV=/m);
  console.log("PASS workspace does not automatically combine child repo environments");
  console.log("NOT TESTED agent instruction auto-loading and nested agent sandbox enforcement");
} finally {
  rmSync(root, { recursive: true, force: true });
}
