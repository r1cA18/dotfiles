# Handoff Schema

`render-handoff.ts`へ渡すJSONは次の形にする。

```json
{
  "title": "Project or feature name",
  "subtitle": "One-line outcome",
  "status": "shipped",
  "generatedAt": "2026-06-28T12:00:00+09:00",
  "summary": "What changed and why it matters.",
  "goal": "The final refined goal.",
  "repository": {
    "name": "owner/repo",
    "url": "https://github.com/owner/repo",
    "branch": "feature/example",
    "commit": "abcdef1",
    "pullRequest": "https://github.com/owner/repo/pull/1"
  },
  "sections": [
    {
      "title": "What was built",
      "items": [
        {
          "label": "Feature",
          "detail": "Description",
          "evidence": "Test or file proving it"
        }
      ]
    }
  ],
  "verification": [
    {
      "name": "Unit tests",
      "command": "bun test",
      "result": "passed",
      "detail": "18 tests passed"
    }
  ],
  "usage": [
    {
      "step": "Run the app",
      "command": "bun run dev",
      "detail": "Open http://localhost:3000"
    }
  ],
  "decisions": [
    {
      "decision": "Use SQLite",
      "reason": "Local-first and zero service dependency",
      "alternatives": "PostgreSQL, JSON files"
    }
  ],
  "cautions": [
    {
      "title": "Migration",
      "detail": "Back up the existing database first."
    }
  ]
}
```

## Required Fields

- `title`
- `subtitle`
- `status`
- `summary`
- `goal`
- `sections`
- `verification`
- `usage`

`repository`、`decisions`、`cautions`は該当する場合だけ入れる。未検証項目は省略せず、`result`を`not-run`または`blocked`にして理由を書く。

## Content Rules

- product copyは丁寧な日本語またはprojectの既存voiceに合わせる。
- command、path、identifierは正確に記載する。
- secret、token、個人dataを含めない。
- 「成功」だけでなくcommandと結果を入れる。
- manual verificationは誰でも再現できる粒度で書く。
