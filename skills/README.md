# Claude Code Skills

`~/.claude/skills/` を agent-skills-nix で宣言的に管理。

## 概要

Skills は Claude Code の能力を拡張するための定義ファイル。
このディレクトリの内容は Nix store を経由して `~/.claude/skills/` に同期される。

## ディレクトリ構造

```
skills/
├── README.md           # このファイル
├── agent-browser/      # 各スキルディレクトリ
│   └── SKILL.md        # スキル定義
├── video-editing/
│   └── SKILL.md
└── ...
```

## スキルの種類

### カスタムスキル（自作）

`skills/` 直下にディレクトリを作成し、`SKILL.md` を配置。
`enableAll = ["custom"]` により自動で有効化。

### 公式スキル

agent-skills-nix が提供するスキル。
`skills.enable = ["pdf", "xlsx", ...]` で有効化。

## 設定ファイル

`nix/home-manager/programs/agent-skills.nix` で管理：

```nix
{
  programs.agent-skills = {
    enable = true;

    # 公式スキルを有効化
    skills.enable = [
      "pdf"
      "xlsx"
    ];

    # カスタムスキルのソースディレクトリ
    customSkillsDir = ../../../skills;

    # カスタムスキルを自動有効化
    enableAll = ["custom"];
  };
}
```

## カスタムスキルの追加

1. `skills/` に新しいディレクトリを作成

   ```bash
   mkdir skills/my-new-skill
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

3. `dr` でビルド・適用

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

- skills は Nix store 経由で同期されるため **read-only**
- 編集は `dotfiles/skills/` で行い、`dr` で適用が必要
- `~/.claude/skills/` を直接編集しても次回の `dr` で上書きされる

## 参考

- [agent-skills-nix](https://github.com/anthropics/agent-skills-nix)
- Claude Code ドキュメント
