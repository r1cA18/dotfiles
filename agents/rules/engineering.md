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

## Progress Records

- At the start of substantial work or a resumed task read its existing progress document under the project's docs before continuing
- For work spanning multiple stages update that document at meaningful milestones and before an interruption or handoff with the objective decisions changes verification results and next action
- Distinguish completed checks from unverified assumptions and remaining work
- Reuse the project's task or session document convention; create one concise document under docs only when no suitable record exists
- Keep records proportional to the task; small changes do not need a progress document and individual tool calls do not need logging
- Respect the document's publication boundary; exclude credentials personal account data private paths and raw session transcripts from shared or public docs

## Code And Git

- Do not use emoji in code comments commit messages or Markdown
- Keep debug output plain and functional
- Use English Conventional Commits when the user requests a commit
- Use `feature/` `fix/` or `docs/` prefixes for new branches
- Avoid direct pushes to `main` except for explicitly approved small changes
