# Harness test and CI audit

## Scope

Reviewed the dotfiles test entrypoints, CI workflows, harness runtime/profile
scripts and their callers, plus Core execution/checkpoint adapters and verification
CI. This is a targeted inventory of the current harness stack, not proof that
every public API in every related repository is used.

## Findings and changes

| Finding | Change | Evidence |
| --- | --- | --- |
| `all` reruns shared tests in both unit and integration modes | Build the Nix fixtures and execute the union once | 73 repeated passing cases removed while retaining generated-package checks |
| Tests in `agents/scripts` are omitted from the common entrypoint | Include that directory in unit and all | 7 existing model-profile/account-launcher tests now execute |
| Fuzzy `no-match` can match the temporary workspace path | Anchor the filter and make the fixture contain `no-match` | Old assertion fails deterministically; fixed case passes on both OSes |
| Core branch push and PR trigger the same expensive workflow | Core follow-up restricts push to main and cancels superseded PR runs | Pull requests and post-merge main verification remain enabled |

The old all entrypoint reports 99 unit passes plus 77 integration passes. Their
union contains 103 distinct passing cases. The new entrypoint runs those 103 plus
the 7 previously omitted cases: 110 passes. This is a case-count comparison, not a
measured runtime or credit-saving claim.

## Retained checks and code

- Native dsh checks require the pinned package and stay in their separate CI step
- Unit mode deliberately skips Nix-generated fixtures; all enables them
- Home Manager build, flake checks and secret scanning check different boundaries
- Model-profile scripts and Orca launcher generation have Nix/runtime callers
- The shared runtime process helper serves both launch and improvement adapters
- Core OpenAPI helper functions generate schema metadata; their annotations do not imply dead code
- Public adapter ports are integration boundaries; lack of an internal caller alone does not justify deleting them

No unreferenced executable was proven safe to remove in this scope. Refactoring
is limited to the duplicate execution and request validation shared by Core's
capture and checkpoint operations. New daemons, platform routing and inactive
extension scaffolding were not added.

## Verification

macOS arm64 and homelab Linux x86_64 each ran `bash scripts/test.sh all` with
110 pass / 3 skip / 0 fail. Those 3 skips are the native dsh suite, which CI invokes
separately with its package path. The deterministic fzf reproduction failed before
the filter correction and passed afterwards.

Tests use private fixtures. No existing service, account login, Home Manager or
system configuration was activated by this audit. See [the test guide](../guides/testing.md)
for the common entrypoints and Nix-provided dependencies.
