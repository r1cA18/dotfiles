# Harness model routing implementation

Objective: independently select dsh or Claude Code and a model/account connection. Preserve existing runtime configuration. Work only in an isolated checkout; do not apply Home Manager, install agent runtimes, log in, start real services, or perform inference.

## Scope 1: connection catalog

Implemented strict configuration validation, explicit group/profile resolution, runtime overrides, immutable selection copies and SHA-256 bindings. Gateway origins are loopback-only; different account scopes cannot share one origin in the catalog. No credentials or automatic fallback are accepted. This resolver is not an authentication authority and cannot attest the account a separately configured gateway actually uses.

Validation: seven focused tests passed (33 assertions). Existing tests were run before changes; final broader results follow below. Current native provider availability and live quota accounting remain unverified.

Next: render per-runtime launch settings and add an explicitly requested launcher with fake-process integration tests. Keep all real runtime services unchanged.

Scope 1 final verification: `bun test tests` passed 43 tests with four Nix-only skips. A sandbox-only failure in an existing PTY test was reproduced before changes; the suite passed when PTY access was available. PR #20 contains this scope.

## Scope 2: runtime rendering and opt-in execution

Added read-only JSON plans, dsh pi-ai Cordis patches and Claude Code process-local gateway settings. Explicit execution uses private HOME/XDG/native state, probes the pinned version, strips ambient credential/route overrides, passes the task as a literal argument, and bounds the process group lifetime. Native success is not recorded as Core verification or approval. An optional, disabled Home Manager module distributes the two CLI entrypoints without importing itself into active host configuration.

The current launcher opens fresh one-shot sessions; native resume, Core adapter integration, authenticated gateway account attestation and persistent quota waiting remain separate work. Tests use fake executables only. No real runtime installation, inference, login, service startup, environment application, or background agent was performed.

Scope 2 validation: the final local suite passed 80 tests with four Nix-only skips (404 assertions). The focused connection/runtime suite passed 18 tests. The optional Nix CLI package built successfully, and its packaged resolver and read-only plan commands returned the expected JSON. Nix parsing, nixfmt, Statix, deadnix, documentation path checks and whitespace checks passed. The final source includes a copied selection and fingerprint check before asynchronous writes. The only initial PR #20 CI failure was Markdown table formatting; the formatting fix was pushed without changing runtime behavior. No broad mutation campaign was run.

## Scope 3: portable profiles and pinned DeepSeek Harness

The shared home configuration now declares the existing launcher module and DeepSeek Harness distribution for the next explicit apply. The module itself remains opt-in for other configurations. No Home Manager activation, native login, existing account inspection, paid inference or global default/model change was performed.

Added a portable profile manifest and device-local executable/gateway bindings as a thin layer over the existing catalog. The read-only doctor identifies missing bindings, account/group mismatches, gateway scope conflicts and unsupported routes. A portable fingerprint stays stable across devices; the concrete execution fingerprint includes local paths and origins. Doctor readiness is configuration validity only and does not attest credentials, binary availability or provider access. Native account state, task ownership, execution history and session migration remain outside this layer.

Subscription routes now fail closed in both the new profile path and the legacy launcher. Anthropic's official terms distinguish native Claude Code login from third-party subscription credential intermediation. OpenAI documents an official OSS Sign in with ChatGPT flow with app/host identity and user consent, but this launcher does not implement that authentication or the required Responses adapter. No subscription plugin or credential-copy route was enabled. Codex is a peer runtime declaration but this gateway launcher does not implement its native transport; existing native launchers remain an explicit user choice.

Pinned the official `@deepseek-ai/dsh@0.2.1-rc.2` tarball, dependency lock and package-private official Node 24.20.0 runtime. The Nix-built Node 22 and 24 binaries passed top-level help but failed native startup on Apple Silicon because the upstream native loader did not recognize the realm-getter machine code. The same package passed with the official Node binary. No loader guard, native addon or provider code was patched. The Linux package uses the same runtime version with Nix loader patching. Its x86_64 build and both synthetic native tests also passed in a disposable source copy. Other supported architectures have fixed hashes but no native execution evidence yet.

Shared instructions reuse `agent-instructions.nix`; the existing selected skill set is deployed as flat native bundles. Explicit launcher assets are attached to each private native home without copying native credentials or plugin state. The instruction digest is recorded, while skill symlinks remain live references rather than snapshots. Nix-managed asset locations use the default `.dsh` home consistently; a separately chosen native `DSH_HOME` requires its own explicit asset setup.

Scope 3 local validation: the final Nix package built on Apple Silicon and passed exact version, top-level help and headless help checks with an isolated home. The packaged runtime completed a synthetic loopback Messages request, a real native read-tool call and the tool-result round trip, with shared instructions and skills observed at the synthetic endpoint. A pending synthetic request was cancelled at the launcher's deadline. `HARNESS_TEST_DSH_BINARY` with the built package and `bun test tests` passed 68 tests, skipped four existing environment-dependent checks and failed none (411 assertions). The focused connection/profile/launcher suite passed 30 tests (128 assertions). The real Darwin and Linux Home Manager configurations both evaluated with the distribution enabled, consistent skill targets and no failed assertions. The three packaged CLI wrappers built and their read-only list/doctor/plan commands passed. Formatting, Statix, deadnix, documentation path checks and whitespace checks passed. No external provider or subscription inference was used.

Review fixes: device bindings reject raw URL whitespace/control characters before URL normalization so doctor and resolution agree; managed dsh skill deployment and wrapper paths no longer depend on the activation process's `DSH_HOME`.

The Linux regression workflow builds the pinned package and explicitly enables both synthetic native tests, so the default skip cannot hide a future native startup regression.

Next: review the stacked PR before any apply. Core/Orca integration, native resume, official ChatGPT sign-in/Responses support, runtime sandboxing and provider account attestation remain separate unfinished work.
