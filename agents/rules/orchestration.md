# Agent Orchestration

## When To Delegate

- Delegate a bounded task when it can progress independently and parallel work or a separate review materially helps the outcome
- Keep small edits and tightly dependent decisions with the current agent
- Use only delegation tools available and permitted in the active session; continue locally when delegation is unavailable

## Assignments And Integration

- Give each agent a concrete question or deliverable with the relevant context and a verifiable completion condition
- For implementation assign file ownership and state that other agents' edits must be preserved
- Keep overlapping edits sequential; use separate worktrees when independent branches are needed
- Send the context needed for the assignment rather than duplicating the full conversation by default
- Continue independent work while delegates run; reuse an existing agent for related follow-ups
- Ask delegates to report evidence, changed files, checks run, and unresolved issues
- The coordinating agent owns scope, resolves disagreements, reviews combined changes, and verifies the integrated result before completion

## Model And Tool Selection

- Match capabilities to the assignment: economical models for bounded exploration and implementation; stronger reasoning for ambiguity, architecture, difficult diagnosis, or consequential review
- Use the active product's available models and supported reasoning settings; keep model IDs and provider-specific tool names in product-specific configuration
- Respect explicit user model choices and configured specialist roles; inherit the current model when no suitable override is available
- Escalate based on concrete uncertainty or failed verification instead of retrying the same ineffective approach
- Use the active product's native delegation first; use an existing cross-product bridge when its capabilities help and the data and action are within the authorized scope
- Delegation does not expand permissions or authorize external messages, publication, purchases, or destructive changes
