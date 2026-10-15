# Harness model routing implementation

Objective: independently select dsh or Claude Code and a model/account connection. Preserve existing runtime configuration. Work only in an isolated checkout; do not apply Home Manager, install agent runtimes, log in, start real services, or perform inference.

## Scope 1: connection catalog

Implemented strict configuration validation, explicit group/profile resolution, runtime overrides, immutable selection copies and SHA-256 bindings. Gateway origins are loopback-only; different account scopes cannot share one origin in the catalog. No credentials or automatic fallback are accepted. This resolver is not an authentication authority and cannot attest the account a separately configured gateway actually uses.

Validation: seven focused tests passed (33 assertions). Existing tests were run before changes; final broader results follow below. Current native provider availability and live quota accounting remain unverified.

Next: render per-runtime launch settings and add an explicitly requested launcher with fake-process integration tests. Keep all real runtime services unchanged.
