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
