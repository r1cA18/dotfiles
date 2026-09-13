#!/usr/bin/env bun
import { chmodSync, cpSync, existsSync, lstatSync, mkdirSync, readdirSync, readFileSync, realpathSync, statSync, symlinkSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";

function run(argv: string[], capture = false): string {
  const result = Bun.spawnSync(argv, { env: process.env, stdin: "inherit", stdout: capture ? "pipe" : "inherit", stderr: "inherit" });
  if (result.exitCode !== 0) throw new Error(`${argv[0]} exited ${result.exitCode}`);
  return capture ? result.stdout.toString().trim() : "";
}

function repository(value: string): { identity: string; url: string } {
  let host: string;
  let path: string;
  let url = value;
  if (value.startsWith("https://") || value.startsWith("ssh://")) {
    const raw = value.match(/^(?:https|ssh):\/\/([^/]+)\/(.+)$/);
    if (!raw || /\s/.test(value)) throw new Error("Invalid repository URL");
    const parsed = new URL(value);
    if (parsed.password || parsed.search || parsed.hash || raw[1].split("@").at(-1)!.includes(":") ||
      (parsed.protocol === "https:" && parsed.username)) throw new Error("Use a repository URL without credentials, port, query, or fragment");
    host = parsed.hostname;
    // Keep the original path: URL parsing normalizes encoded dot segments.
    path = raw[2];
  } else {
    const ssh = value.match(/^([a-zA-Z0-9_-]+)@([a-zA-Z0-9.-]+):(.+)$/);
    if (ssh) [, , host, path] = ssh;
    else {
      const slash = value.indexOf("/");
      host = value.slice(0, slash);
      path = value.slice(slash + 1);
      url = `https://${value}`;
    }
  }
  path = path.replace(/\.git$/, "");
  if (!/^[a-zA-Z0-9][a-zA-Z0-9.-]*$/.test(host) ||
    !/^[a-zA-Z0-9_.-]+(?:\/[a-zA-Z0-9_.-]+)+$/.test(path) ||
    path.split("/").some(part => part === "." || part === "..")) throw new Error("Invalid repository URL or host/owner/repo path");
  return { identity: `${host.toLowerCase()}/${path}`, url };
}

function entries(data: unknown = JSON.parse(readFileSync("repos.json", "utf8"))): [string, string][] {
  if (!data || Array.isArray(data) || typeof data !== "object") throw new Error("repos.json must be an alias-to-repository-URL object");
  const result = Object.entries(data);
  for (const [alias, repo] of result) {
    if (!/^[a-zA-Z0-9][a-zA-Z0-9_-]*$/.test(alias) || typeof repo !== "string") {
      throw new Error(`Invalid repository entry: ${alias}`);
    }
    repository(repo);
  }
  if (new Set(result.map(([alias]) => alias.toLowerCase())).size !== result.length) throw new Error("Duplicate repository aliases (case-insensitive)");
  if (new Set(result.map(([, repo]) => repository(repo).identity)).size !== result.length) throw new Error("Duplicate repository paths");
  return result as [string, string][];
}

function checkoutMode(): "local" | "ghq" {
  // Workspaces generated before workspace.json used ghq links.
  if (!existsSync("workspace.json")) return "ghq";
  const config = JSON.parse(readFileSync("workspace.json", "utf8"));
  if (config?.checkout !== "local" && config?.checkout !== "ghq") throw new Error('workspace.json checkout must be "local" or "ghq"');
  return config.checkout;
}

type Agent = "codex" | "claude";
const profileManagers = { codex: "cxp", claude: "clp" };

function savedProfile(agent: Agent): string | undefined {
  const root = Bun.spawnSync(["git", "rev-parse", "--show-toplevel"], { stdout: "pipe", stderr: "pipe" });
  if (root.exitCode !== 0 || realpathSync(root.stdout.toString().trim()) !== realpathSync(process.cwd())) return;
  const result = Bun.spawnSync(["git", "config", "--local", "--no-includes", "--get", `workspace.${agent}Profile`], { stdout: "pipe", stderr: "pipe" });
  if (result.exitCode === 1) return;
  if (result.exitCode !== 0) throw new Error("Cannot read workspace profile configuration");
  const value = result.stdout.toString().trim();
  if (!value || /[\r\n]/.test(value)) throw new Error(`Invalid ${agent} profile; run ws profile ${agent} again`);
  return value;
}

function configureProfile(args: string[]) {
  entries();
  checkRoot(".");
  if (!args.length) {
    for (const agent of ["codex", "claude"] as const) console.log(`${agent}: ${savedProfile(agent) || "not configured (inherits environment)"}`);
    return;
  }
  const [agent, option] = args;
  if ((agent !== "codex" && agent !== "claude") || args.length > 2 || (option && option !== "--clear")) {
    throw new Error("Usage: ws profile [codex|claude [--clear]]");
  }
  const key = `workspace.${agent}Profile`;
  if (option === "--clear") {
    if (savedProfile(agent)) run(["git", "config", "--local", "--unset-all", key]);
    console.log(`${agent}: profile cleared`);
    return;
  }
  const manager = profileManagers[agent];
  if (!Bun.which(manager) || !Bun.which("fzf")) throw new Error(`${manager} and fzf are required; use your Nix environment to provide them`);
  const rows = run([manager, "list"], true).split("\n").slice(1).filter(Boolean);
  if (!rows.length) throw new Error(`No profiles found; run ${manager} add first`);
  const selected = Bun.spawnSync([
    "fzf", "--delimiter=\t", "--with-nth=1,2", "--reverse", "--height=40%",
    "+m", "--no-print-query", "--no-expect", `--prompt=${agent} profile> `,
  ], { stdin: Buffer.from(rows.join("\n") + "\n"), stdout: "pipe", stderr: "inherit" });
  if (selected.exitCode === 1 || selected.exitCode === 130) return;
  if (selected.exitCode !== 0) throw new Error("Profile selection failed; retry ws profile");
  const row = selected.stdout.toString().trimEnd();
  if (!rows.includes(row)) throw new Error("Invalid profile selection");
  const selector = row.split("\t")[0];
  if (!selector) throw new Error("Invalid profile selector");
  run([manager, "path", selector], true);
  run(["git", "config", "--local", "--replace-all", key, selector]);
  console.log(`${agent}: ${selector}`);
}

function agentCommand(agent: Agent): string[] {
  const profile = savedProfile(agent);
  if (!profile) return [agent];
  const manager = profileManagers[agent];
  if (!Bun.which(manager)) throw new Error(`${manager} is required for the saved profile; restore it or run ws profile ${agent} --clear`);
  return [manager, "run", profile];
}

function writeManifest(data: Record<string, string>) {
  entries(data);
  if (!lstatSync("repos.json").isFile()) throw new Error("repos.json must be a regular file");
  writeFileSync("repos.json", JSON.stringify(data, null, 2) + "\n");
}

function add(args: string[]) {
  if (args.length < 1 || args.length > 2) throw new Error("Usage: ws add <repository-URL> [alias]");
  const [repo, name] = args;
  const alias = name || repository(repo).identity.split("/").at(-1)!.replace(/\./g, "-");
  const data = Object.fromEntries(entries());
  if (Object.hasOwn(data, alias)) throw new Error(`Alias already registered: ${alias}`);
  writeManifest({ ...data, [alias]: repo });
  console.log(`Registered ${alias} in repos.json. If sync fails, fix the reported issue and run ./ws sync again.`);
  sync();
}

function remove(args: string[]) {
  if (args.length !== 1) throw new Error("Usage: ws remove <alias>");
  const data = Object.fromEntries(entries());
  if (!Object.hasOwn(data, args[0])) throw new Error(`Unknown repository alias: ${args[0]}`);
  delete data[args[0]];
  writeManifest(data);
  console.log(`Unregistered ${args[0]}. Checkout and indexes were kept on disk.`);
}

function checkRoot(path: string): string {
  const root = realpathSync(path);
  if (realpathSync(run(["git", "-C", root, "rev-parse", "--show-toplevel"], true)) !== root) {
    throw new Error(`Not a repository root: ${path}`);
  }
  return root;
}

function checkReposDirectory() {
  const stat = lstatSync("repos", { throwIfNoEntry: false });
  if (stat && !stat.isDirectory()) throw new Error("repos must be a real directory, not a symlink or file");
}

function linked(): [string, string, string][] {
  checkReposDirectory();
  const mode = checkoutMode();
  const ghqRoot = mode === "ghq" ? run(["ghq", "root"], true) : "";
  return entries().map(([alias, repo]) => {
    const path = `repos/${alias}`;
    const stat = lstatSync(path, { throwIfNoEntry: false });
    if (!(mode === "ghq" ? stat?.isSymbolicLink() : stat?.isDirectory())) throw new Error(`Run ws sync first; unexpected or missing checkout: ${path}`);
    const root = checkRoot(path);
    if (mode === "ghq") {
      const expected = join(ghqRoot, repository(repo).identity);
      if (!existsSync(expected) || root !== realpathSync(expected)) throw new Error(`Manifest/link mismatch: ${alias}; check repos.json and run ws sync`);
    } else checkOrigin(path, repo);
    return [alias, repo, root];
  });
}

function checkOrigin(path: string, repo: string) {
  const origin = run(["git", "-C", path, "config", "--get", "remote.origin.url"], true);
  if (repository(origin).identity !== repository(repo).identity) throw new Error(`Manifest/origin mismatch: ${path}; check repos.json and the checkout remote`);
}

function sync() {
  checkReposDirectory();
  const mode = checkoutMode();
  const ghqRoot = mode === "ghq" ? run(["ghq", "root"], true) : "";
  if (mode === "ghq" && !ghqRoot.startsWith("/")) throw new Error("ghq root must be absolute");
  const repos = entries();
  // Validate existing paths before cloning anything.
  for (const [alias, repo] of repos) {
    const link = `repos/${alias}`;
    const stat = lstatSync(link, { throwIfNoEntry: false });
    if (stat) {
      if (mode === "local") {
        if (!stat.isDirectory()) throw new Error(`Refusing to replace existing path: ${link}`);
        checkRoot(link);
        checkOrigin(link, repo);
      } else {
        const target = join(ghqRoot, repository(repo).identity);
        if (!stat.isSymbolicLink() || !existsSync(link) || !existsSync(target) || realpathSync(link) !== realpathSync(target)) {
          throw new Error(`Refusing to replace existing path: ${link}`);
        }
        checkRoot(link);
      }
    }
  }
  for (const [alias, repo] of repos) {
    mkdirSync("repos", { recursive: true });
    if (mode === "local") {
      if (!existsSync(`repos/${alias}`)) run(["git", "clone", "--", repository(repo).url, `repos/${alias}`]);
      checkRoot(`repos/${alias}`);
      checkOrigin(`repos/${alias}`, repo);
    } else {
      const target = join(ghqRoot, repository(repo).identity);
      if (!existsSync(target)) run(["ghq", "get", repository(repo).url]);
      const root = checkRoot(target);
      if (!existsSync(`repos/${alias}`)) symlinkSync(root, `repos/${alias}`);
    }
  }
  console.log(`Synced ${repos.length} repositories (${mode}).`);
}

function snapshot(verify: boolean) {
  const current = Object.fromEntries(linked().map(([alias, repo, path]) => {
    if (run(["git", "-C", path, "status", "--porcelain"], true)) throw new Error(`Uncommitted changes: ${alias}`);
    return [alias, { repo, commit: run(["git", "-C", path, "rev-parse", "HEAD"], true) }];
  }));
  if (verify) {
    const expected = JSON.parse(readFileSync("repos.lock.json", "utf8"));
    if (Object.keys(expected).length !== Object.keys(current).length ||
      Object.entries(current).some(([key, value]) => expected[key]?.repo !== value.repo || expected[key]?.commit !== value.commit)) {
      throw new Error("Repository revisions differ from repos.lock.json; check ws status (no checkout was changed)");
    }
    console.log("Repository revisions match; all checkouts are clean");
  } else {
    const stat = lstatSync("repos.lock.json", { throwIfNoEntry: false });
    if (stat && !stat.isFile()) throw new Error("Refusing to overwrite non-regular repos.lock.json");
    writeFileSync("repos.lock.json", JSON.stringify(current, null, 2) + "\n");
  }
}

function init(target: string | undefined) {
  if (!target) throw new Error("Usage: workspace init <new-directory>");
  const source = resolve(dirname(import.meta.path), "../..");
  const template = process.env.WORKSPACE_TEMPLATE_DIR || join(source, "templates/workspace");
  const packageFile = process.env.WORKSPACE_INDEXION_NIX || join(source, "nix/pkgs/indexion/default.nix");
  if (!existsSync(packageFile)) throw new Error("Workspace package source is unavailable");
  mkdirSync(dirname(resolve(target)), { recursive: true });
  mkdirSync(target); // Exclusive: never merge a template into existing work.
  cpSync(template, target, { recursive: true, force: false, errorOnExist: true });
  mkdirSync(join(target, "scripts"), { recursive: true });
  cpSync(import.meta.path, join(target, "scripts/workspace.ts"));
  mkdirSync(join(target, "nix"), { recursive: true });
  cpSync(packageFile, join(target, "nix/indexion.nix"));
  // Nix store sources are read-only; generated workspace files must be editable.
  for (const path of [target, ...readdirSync(target, { recursive: true }).map(path => join(target, path))]) {
    chmodSync(path, statSync(path).mode | 0o200);
  }
  run(["git", "init", "--", resolve(target)]);
  console.log(`Created ${resolve(target)}. Run ./ws add <repository-URL> [alias] there, then edit AGENTS.md. Nix is optional.`);
}

function clone(args: string[]) {
  if (args.length !== 2) throw new Error("Usage: workspace clone <workspace-URL> <new-directory>");
  const [remote, target] = args;
  const url = repository(remote).url;
  if (lstatSync(target, { throwIfNoEntry: false })) throw new Error(`Refusing to replace existing path: ${target}`);
  mkdirSync(dirname(resolve(target)), { recursive: true });
  run(["git", "clone", "--", url, target]);
  process.chdir(target);
  // Use this CLI; do not execute scripts from the downloaded repository.
  sync();
}

function main() {
  const [command, ...args] = process.argv.slice(2);
  if (!command || command === "help" || command === "--help") {
    console.log("workspace init <dir> | clone <workspace-URL> <dir> | add <repository-URL> [alias] | remove <alias> | sync | status | snapshot | verify | rg <args...> | search <query> | orient <task> | index | query <purpose> | codex [args...] | claude [args...]\nCore: Git + Bun. Optional: ghq for ghq mode; ripgrep for rg; indexion for index/search/query/orient; agent CLI for codex/claude.");
    console.log("workspace profile [codex|claude [--clear]]: select a saved account with fzf, show settings, or clear one. Requires cxp/clp and fzf.");
    return;
  }
  if (command === "init") return init(args[0]);
  if (command === "clone") return clone(args);
  if (command === "add") return add(args);
  if (command === "remove") return remove(args);
  if (command === "profile") return configureProfile(args);
  if (command === "sync") return sync();
  if (command === "snapshot" || command === "verify") return snapshot(command === "verify");
  const repos = linked();
  const paths = repos.map(([, , path]) => path);
  if (!repos.length && ["rg", "search", "query", "orient", "index"].includes(command)) throw new Error("Add repositories with ws add first");
  const indexion = process.env.INDEXION_BIN || "indexion";
  switch (command) {
    case "status":
      for (const [alias, , path] of repos) {
        console.log(`${alias}: ${path}`);
        run(["git", "-C", path, "status", "--short", "--branch"]);
        run(["git", "-C", path, "rev-parse", "HEAD"]);
      }
      break;
    case "rg":
      run(["rg", ...args, ...repos.map(([alias]) => `repos/${alias}/`)]);
      break;
    case "search":
      if (!args.length) throw new Error("Usage: ws search <query>");
      for (const [alias, , path] of repos) {
        if (!existsSync(`.indexion/digest/${alias}`)) throw new Error("Run ws index before searching");
        console.log(`Repository: ${alias}`);
        run([indexion, "digest", "query", "--provider=tfidf", `--index-dir=.indexion/digest/${alias}`, `--source=${path}`, args.join(" ")]);
      }
      if (existsSync(".indexion/wiki/wiki.json")) {
        console.log("Workspace knowledge:");
        run([indexion, "search", "--provider=tfidf", args.join(" "), ".indexion/wiki"]);
      }
      break;
    case "orient":
      run([indexion, "agent", "orient", "--rescan", "--task", args.join(" "), ...paths]);
      break;
    case "index":
      // digest accepts one source directory; keep independent indexes under one workspace.
      for (const [alias, , path] of repos) run([indexion, "digest", "build", "--provider=tfidf", `--index-dir=.indexion/digest/${alias}`, path]);
      if (existsSync(".indexion/wiki/wiki.json")) run([indexion, "wiki", "index", "build", "--full", "--provider=tfidf"]);
      break;
    case "query":
      if (!args.length) throw new Error("Usage: ws query <purpose>");
      for (const [alias, , path] of repos) {
        console.log(`Repository: ${alias}`);
        run([indexion, "digest", "query", "--provider=tfidf", `--index-dir=.indexion/digest/${alias}`, `--source=${path}`, args.join(" ")]);
      }
      break;
    case "codex":
      run([...agentCommand("codex"), "-C", process.cwd(), ...paths.flatMap(path => ["--add-dir", path]), ...args]);
      break;
    case "claude":
      process.env.CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD = "1";
      run([...agentCommand("claude"), ...args, ...paths.flatMap(path => ["--add-dir", path])]);
      break;
    default:
      throw new Error(`Unknown command: ${command}`);
  }
}

try { main(); } catch (error) {
  console.error(error instanceof Error ? error.message : error);
  process.exitCode = 1;
}
