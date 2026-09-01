# Engineering Behavior

## Think Before Coding

- State assumptions explicitly
- Present multiple interpretations when they materially change the solution
- Explain simpler alternatives and relevant tradeoffs
- Stop and ask when missing information makes a safe choice impossible

## Simplicity

- Write the minimum code needed for the requested behavior
- Do not add speculative features or configurability
- Do not add abstractions for a single use unless they remove real complexity
- Prefer existing project patterns over new conventions

## Surgical Changes

- Touch only lines required by the request
- Do not refactor unrelated code
- Match the existing style
- Remove only unused code created by the current change
- Mention unrelated problems without changing them

## Goal-Driven Execution

- Define verifiable success criteria for non-trivial work
- Reproduce bugs before fixing them when practical
- Run relevant tests before and after risky changes
- Verify builds and user-facing behavior before declaring completion
- Continue until the requested outcome is complete or genuinely blocked

## Code And Git

- Do not use emoji in code comments commit messages or Markdown
- Keep debug output plain and functional
- Use English Conventional Commits when the user requests a commit
- Use `feature/` `fix/` or `docs/` prefixes for new branches
- Avoid direct pushes to `main` except for explicitly approved small changes
