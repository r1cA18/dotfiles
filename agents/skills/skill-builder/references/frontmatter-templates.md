# Frontmatter Templates

必要な能力と適用条件を記述する。triggerの個数や日英の併記を必須にしない。

## Minimal

```yaml
---
name: example-skill
description: Validate repository manifests when adding repositories or reviewing manifest changes.
---
```

nameとdescriptionを対象用途へ変更する。nameは文字列で記述し波括弧によるYAML mappingにしない。

## Multiline

```yaml
---
name: example-skill
description: |
  Validate repository manifests and explain failed entries.
  Use for manifest maintenance rather than cloning unrelated repositories.
---
```

workflowの詳細は本文へ置く。呼び出し例は境界を明確にする場合だけ加える。

## Compatibility

- nameは64文字以下のkebab-caseとし配布IDとの対応を確認する
- descriptionは空でない文字列とし共有validatorでは1024文字以内を確認する
- licenseやmetadataは実際の配布要件がある場合だけ追加する
- allowed-toolsなど製品固有fieldは対象runtimeの対応を確認する
- fieldを省略してもsessionの権限やsandbox制約を解除できるわけではない
- Claudeのtool名をCodexにも使えると仮定しない

YAMLの構文・必須field・参照fileをvalidatorで確認する。静的検証の成功と実agentでの発火精度は別に記録する。
