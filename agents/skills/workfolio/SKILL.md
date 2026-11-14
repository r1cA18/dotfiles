---
name: workfolio
description: >-
  Uses the owner's Workfolio (self-hosted time, contracts, expenses, invoices and income) through its MCP tools: check the running timer, start, switch or stop work, record actual breaks and past sessions, total worked hours by period and company, run the overtime and contract-limit checks, list and add expenses, calculate and draft invoices, record payments, and (personal group) read income, annual tax preparation figures and dependency/insurance estimates. Use when the owner asks about work time, overtime, invoices, payments, expenses or income. Triggers: "start my timer", "how many hours this week", "draft the invoice". 日本語: 「作業開始」「休憩」「今日は終わり」「今週何時間働いた」「残業」「上限」「経費を登録」「請求書を作って」「請求額を計算」「入金があった」「今年の所得」「扶養の範囲」
---

# Workfolio

Workfolio is the owner's own record of work and money. Its MCP server
(`workfolio_*` tools) talks only to the Workfolio API with the token of the
current r1hn group. Every figure comes from Workfolio's code; do not compute
hours, taxes or invoice totals yourself.

## Group boundary

- The tools see only the companies mapped to this session's group. A company
  group never sees another company or the personal records; `personal` sees
  its own companies plus income, assets, tax and forecast, not company groups'
  time or contracts
- A 404 for an id you got elsewhere means it belongs to another group. Do not
  try another token, an unscoped token, the database or the files
- `workfolio_whoami` tells the group and scopes. Without write scopes there are
  no write tools; say what the owner would have to do in the Workfolio UI

## Work flow

1. Read first: `workfolio_companies` for project ids, `workfolio_timer_status`
   before starting or stopping
2. Calculate before writing: `workfolio_work_summary` or
   `workfolio_labor_checks` for hours and limits, `workfolio_calculate_invoice`
   before `workfolio_draft_invoice`
3. Confirm with the owner before a write unless the request already named the
   project and time ("作業開始して" for a single obvious project is enough).
   Always confirm amounts, dates and the company for expenses, invoices and
   payments
4. Report what Workfolio stored (ids, times, totals) in Japanese plain style

## Rules of the data

- Breaks are actual breaks only. Never add a break the owner did not take, and
  never deduct one automatically
- One timer for the whole owner. A start or switch that fails with 409 may mean
  another group's session runs; tell the owner to stop it there
- Times are ISO instants with an offset; periods use Asia/Tokyo. Amounts are
  decimal strings in JPY
- Checks with `assessed: false` are not judgements. Never call a period
  compliant, legal or safe; repeat Workfolio's message and source link
- Forecasts and tax summaries are estimates and preparation data, not a return
  or an entitlement
- Issuing, cancelling, attaching documents, changing companies and group
  mapping stay with the owner in the UI

## Setup (owner)

1. In Workfolio, set each company's エージェントのグループ to the r1hn group
2. Issue one API token per group in 設定 > APIトークン with that group; a
   read-only token (`read:work`, `read:billing`) for groups that only look
3. Store it as a file readable only by the owner and reference it in r1hn:
   `[env.<group>] WORKFOLIO_TOKEN = "file:env/<group>/workfolio"`
4. Enable the `workfolio` MCP entry or the `work` bundle for the project

Details: `docs/mcp.md` and `docs/integrations.md` in the Workfolio repository.
