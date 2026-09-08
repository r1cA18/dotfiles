import { afterEach, expect, test } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const roots: string[] = [];
const shellTools = resolve("nix/home-manager/programs/zsh-tools.zsh");
const quote = (value: string) => `'${value.replaceAll("'", "'\\''")}'`;

afterEach(() => {
  for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true });
});

function fixture() {
  const root = realpathSync(mkdtempSync(join(tmpdir(), "shell-tools-test-")));
  roots.push(root);
  const detail = `Workspace usage\nws init ~/Workspaces/product\nLiteral $(touch ${root}/executed) and 'quotes'`;
  const setup = `
typeset -g _dotfiles_help_descriptions='[Workspace]\nws - Manage workspace'
typeset -g _dotfiles_help_commands='[Workspace]\nws = workspace'
typeset -ga _dotfiles_help_entries=(${quote(`ws\tWorkspace\tManage workspace\t${detail}`)})
typeset -gA _dotfiles_managed_abbrs=(ws 1)
abbr() {
  case "$1" in
    list-abbreviations) print -rl -- ws runtime ;;
    expand) print -r -- "echo runtime" ;;
  esac
}
source ${quote(shellTools)}
`;
  const run = (code: string, extraEnv: Record<string, string> = {}) => {
    const result = Bun.spawnSync(["zsh", "-f", "-c", setup + code], {
      cwd: root,
      env: { ...process.env, HOME: root, FZF_DEFAULT_OPTS: "", FZF_DEFAULT_OPTS_FILE: "", ...extraEnv },
      stdout: "pipe", stderr: "pipe",
    });
    return { code: result.exitCode, out: result.stdout.toString(), err: result.stderr.toString() };
  };
  const workspace = (name: string) => {
    const path = join(root, "Workspaces", name);
    mkdirSync(path, { recursive: true });
    writeFileSync(join(path, "repos.json"), "{}\n");
    return path;
  };
  return { root, setup, run, workspace, detail };
}

test("piped help retains filters, expansions and deduplicated runtime abbreviations", () => {
  const { run } = fixture();
  const all = run("h");
  expect(all.code).toBe(0);
  expect(all.out).toContain("[Workspace]\nws - Manage workspace");
  expect(all.out).toContain("[Runtime abbreviations]\nruntime = echo runtime");
  expect(all.out).not.toContain("ws = echo runtime");
  expect(run("h WORKSPACE").out).not.toContain("runtime");
  expect(run("hv '^ws ='").out).toBe("ws = workspace\n");
  expect(run("h no-such-command").code).toBe(1);
});

test("real fzf selects multiline help as literal text without executing commands", () => {
  const { run, detail, root } = fixture();
  const result = run("hp", { FZF_DEFAULT_OPTS: "--filter=workspace" });
  expect(result.code).toBe(0);
  expect(result.out).toBe(detail + "\n");
  expect(existsSync(join(root, "executed"))).toBe(false);
  expect(run("hp", { FZF_DEFAULT_OPTS: "--filter=runtime" }).out).toBe("runtime = echo runtime\n");
});

test("workspace discovery prunes child repos and metadata and preserves unusual paths", () => {
  const { run, root, workspace } = fixture();
  const selected = workspace("team/odd ' workspace\n");
  workspace("team/odd ' workspace\n/repos/child");
  workspace(".git/hidden");
  workspace("node_modules/hidden");
  mkdirSync(join(root, "Workspaces", "not a workspace"));
  const discovery = run(`_dotfiles_workspaces ${quote(join(root, "Workspaces"))}`);
  expect(discovery.out.split("\0").filter(Boolean)).toEqual([selected]);
  const result = run("wsg; printf '%s\\0' \"$PWD\"", { FZF_DEFAULT_OPTS: "--filter=odd" });
  expect(result.code).toBe(0);
  expect(result.out).toBe(selected + "\0");
});

test("workspace picker supports a root argument, missing root, no matches and cancellation", () => {
  const { run, root, workspace } = fixture();
  const selected = workspace("custom/project");
  expect(run(`wsg ${quote(join(root, "Workspaces/custom"))}; pwd`, { FZF_DEFAULT_OPTS: "--filter=project" }).out).toBe(selected + "\n");
  expect(run("wsg /path/that/does/not/exist").code).toBe(1);
  expect(run("wsg a b").code).toBe(2);
  expect(run("wsg; pwd", { FZF_DEFAULT_OPTS: "--filter=no-match" }).out).toBe(root + "\n");
  const cancelled = run("fzf() { return 130; }; wsg; result=$?; print -r -- $result:$PWD");
  expect(cancelled.out).toBe(`0:${root}\n`);
  expect(run("fzf() { return 2; }; wsg").code).toBe(2);
});

test("devg still combines ghq and local repositories without duplicate rows", () => {
  const { run, root } = fixture();
  const local = join(root, "Develop/local/project");
  mkdirSync(local, { recursive: true });
  const result = run(`
ghq() { if [[ "$1" == root ]]; then print -r -- ${quote(join(root, "Develop"))}; else print -r -- ${quote(local)}; fi; }
devg
pwd
`, { FZF_DEFAULT_OPTS: "--filter=project" });
  expect(result.code).toBe(0);
  expect(result.out).toBe(local + "\n");
});

test("real terminal help opens fzf preview and Escape closes without running the example", () => {
  const { root, setup } = fixture();
  const script = join(root, "terminal.zsh");
  writeFileSync(script, setup + "h\nprint -r -- HELP_CLOSED\n");
  // A real PTY verifies the no-argument TTY branch and preview subprocess.
  const result = Bun.spawnSync(["python3", "-c", `
import fcntl, os, pty, select, signal, struct, sys, termios, time
pid, fd = pty.fork()
if pid == 0:
    os.environ.update(TERM="xterm-256color", FZF_DEFAULT_OPTS="", FZF_DEFAULT_OPTS_FILE="")
    os.execvp("zsh", ["zsh", "-f", sys.argv[1]])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 160, 0, 0))
output = b""
deadline = time.monotonic() + 8
closed = False
try:
    while time.monotonic() < deadline:
        if select.select([fd], [], [], 0.1)[0]:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            output += chunk
            # fzf height mode requests the cursor position from its terminal.
            if b"\\x1b[6n" in chunk:
                os.write(fd, b"\\x1b[1;1R")
            if b"Workspace usage" in output and not closed:
                os.write(fd, b"\\x1b")
                closed = True
            if b"HELP_CLOSED" in output:
                break
    assert b"Workspace usage" in output, repr(output)
    assert b"HELP_CLOSED" in output, repr(output)
finally:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    os.waitpid(pid, 0)
    os.close(fd)
`, script], { stdout: "pipe", stderr: "pipe" });
  expect(result.stderr.toString()).toBe("");
  expect(result.exitCode).toBe(0);
  expect(existsSync(join(root, "executed"))).toBe(false);
}, 15_000);
