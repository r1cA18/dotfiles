# Agent Skills

`agents/skills/` を agent-skills-nix で宣言的に管理。

## 概要

Skills はエージェントの能力を拡張するための定義ファイル。
このディレクトリの内容は Nix store を経由して `~/.claude/skills/` と `~/.codex/skills/` に同期される。

## ディレクトリ構造

```
agents/skills/
├── README.md           # このファイル
├── agent-browser/      # 各スキルディレクトリ
│   └── SKILL.md        # スキル定義
├── video-editing/
│   └── SKILL.md
└── ...
```

## スキルの種類

### カスタムスキル（自作）

`agents/skills/` 直下にディレクトリを作成し、`SKILL.md` を配置。
`nix/home-manager/programs/agent-skills.nix` の `skills.enable` にIDを追加して有効化。

### 公式スキル

agent-skills-nix が提供するスキル。
`skills.enable = ["pdf", "xlsx", ...]` で有効化。

## 設定ファイル

`nix/home-manager/programs/agent-skills.nix` で管理：

```nix
{
  programs.agent-skills = {
    enable = true;

    sources.custom.path = ../../../agents/skills;

    skills = {
      enable = [ "agent-browser" "pdf" "xlsx" ];
    };
  };
}
```

## カスタムスキルの追加

1. `agents/skills/` に新しいディレクトリを作成

   ```bash
   mkdir agents/skills/my-new-skill
   ```

2. `SKILL.md` を作成

   ```markdown
   ---
   name: my-new-skill
   description: スキルの説明
   triggers:
     - "トリガーワード1"
     - "トリガーワード2"
   ---

   # My New Skill

   スキルの詳細な指示...
   ```

3. `nix/home-manager/programs/agent-skills.nix` の `skills.enable` に `my-new-skill` を追加

4. `dr` でビルド・適用

   ```bash
   dr
   ```

## 公式スキルの有効化

1. `nix/home-manager/programs/agent-skills.nix` を編集

   ```nix
   skills.enable = [
     "pdf"
     "xlsx"
     "new-skill"  # 追加
   ];
   ```

2. `dr` でビルド・適用

## 注意事項

- skills 本体は Nix store 経由で同期されるため **read-only**
- 設定やキャッシュが必要なスキルは `~/.config/agent-skills/` や `~/.local/share/agent-skills/` を使う
- 編集は `dotfiles/agents/skills/` で行い、`dr` で適用が必要
- `~/.claude/skills/` / `~/.codex/skills/` を直接編集しても次回の `dr` で上書きされる
- 同梱ファイル参照は `agent-skill-path <skill> [relative/path]` を使う

## 参考

- [agent-skills-nix](https://github.com/Kyure-A/agent-skills-nix)
- Claude Code ドキュメント
