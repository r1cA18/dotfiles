# Account identity is provider + immutable Orca ID. Email is display metadata.
.result
| to_entries[]
| select(.key == "claude" or .key == "codex")
| .key as $provider
| .value.accounts[]
| if (.id | type) != "string" or (.id | test("^[A-Za-z0-9_-]+$") | not)
  then error("unsupported Orca account ID") else . end
| [$provider, .id, (.email // "(unknown)"),
   (if $provider == "claude" then "cc-orca-" else "cx-orca-" end) + .id]
| @tsv
